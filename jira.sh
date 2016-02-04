#!/bin/bash

function jira {

  USAGE='
  Usage

    jira [subcommand]


  Usage examples

    jira search "validation enhancements"

    echo "ABC-1234" | jira info

    cat file_with_issue_names.txt | jira status

    echo "ABC-123,ABC-456,ABC-789" | tr "," "\n" | jira title

    jira link <<< "ABC-1234"


  Subcommands

    ok            checks if everything is ok, by issuing a /myself
    search [term] search issues by search term


  Subcommands that take newline-separated issues from STDIN

    info          returns basic info about an issue: number, title, asignee, status and last update date
    raw           returns the raw JSON output from the REST API response (pretty print)
    raw [jq-exp]  raw allows you to add a valid jq parsing expression
    link          returns e.g. -> https://company.atlassian.net/browse/ABC-1234
    title         returns e.g. -> Look for and remove all SQL injections
    issuetype     returns e.g. -> Epic
    project       returns e.g. -> New Website
    created       returns e.g. -> 2016-01-22T10:58:30.162+1300
    creator       returns e.g. -> John Doe
    reporter      returns e.g. -> John Doe
    updated       returns e.g. -> 2016-01-22T10:58:30.162+1300
    assignee      returns e.g. -> John Doe
    status        returns e.g. -> Open
  '

  if [[ ! -f ~/.jiraconfig ]]; then
		cat <<- 'EOF' > ~/.jiraconfig
		# Please modify the following configuration values in order to be able to
		# use jira-cli properly!


		# auth holds your BasicAuth credentials; it should be:
		#
		# base64_encode(your_jira_username:your_jira_password)
		# IMPORTANT: don't use your EMAIL, use your USERNAME
		#
		# e.g. if your username is 'user' and your password is 'pass', then:
		#
		# base64_encode("user:pass") = dXNlcjpwYXNz
		#
		# so:
		#
		# auth = dXNlcjpwYXNz
		#
		auth = dXNlcjpwYXNz


		# domain should be the same url domain as the one you see in the location bar
		# of your browser when browsing a Jira issue
		#
		# e.g. if a browser tab showing a Jira issue shows the following url:
		#
		# https://abccompany.atlassian.net/browse/ABC-1234
		#
		# then:
		#
		# domain = https://abccompany.atlassian.net
		#
		domain = https://yourdomain.atlassian.net


		# projects is optional. In large organizations, Jira holds many projects;
		# chances are when you are searching for an issue you will want to look around
		# in only a few of those projects.
		#
		# e.g. if you only want to search in the ABC and DEF projects
		#
		# projects = ABC,DEF
		#
		# Note that ABC is the prefix on the issue code, e.g.
		# https://abccompany.atlassian.net/browse/ABC-1234
		#
		# If you don't want to use this feature, please comment it out
		#
		projects = ABC,DEF
		EOF

    ${EDITOR:-${VISUAL:-vi}} ~/.jiraconfig
    return 1
  fi

  if [[ $# -eq 0 ]]; then
    echo "$USAGE" >&2
    return 1
  else
    COMMAND=$1
  fi

  JIRA_AUTH=$(awk '/^auth/{print $3}' ~/.jiraconfig)
  JIRA_DOMAIN=$(awk '/^domain/{print $3}' ~/.jiraconfig)
  JIRA_PROJECTS=$(awk '/^projects/{print $3}' ~/.jiraconfig)

  if [[ -z "$JIRA_AUTH" ]]; then
    echo >&2
    echo "  I found ~/.jiraconfig, but I didn't find BasicAuth credentials :(" >&2
    echo "$NO_CONFIG_FILE" >&2
    return 1
  fi

  if [[ -z "$JIRA_DOMAIN" ]]; then
    echo >&2
    echo "  I found ~/.jiraconfig, but I didn't find which domain I should request against :(" >&2
    echo "$NO_CONFIG_FILE" >&2
    return 1
  fi

  if [[ $COMMAND == "ok" ]]; then
    CURL=$(curl --silent -LI --header "Authorization: Basic ${JIRA_AUTH}" --header "Content-Type: application/json" -XGET ${JIRA_DOMAIN}/rest/api/2/myself | head -n1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

    if [[ "$CURL" == "HTTP/1.1 200 OK" ]]; then
      echo "OK"
      return 0
    else
      echo "NOT OK. REST API returned [${CURL}] to a /myself GET request."
      return 1
    fi
  fi

  if ! command -v "jq" >/dev/null 2>&1; then
    echo 'This command depends on jq. Please install it before using this!' >&2

    case "$(uname)" in
      Darwin)
        echo "Try 'brew install jq'" >&2
        ;;
      Linux)
        echo "Try 'sudo apt-get install jq'" >&2
        ;;
      *)
        echo "I don't know how to install jq in your OS; please go to https://stedolan.github.io/jq/ and figure it out!" >&2
        ;;
    esac

    return 1
  fi

  if [[ $COMMAND == "search" ]] || [[ $COMMAND == "s" ]]; then
    SEARCH="$2"

    if [[ -z $SEARCH ]]; then
      echo >&2
      echo "  Usage: jira search [search_term] " >&2
      return 1
    fi

    if [[ -z $JIRA_PROJECTS ]]; then
      PROJECT_CLAUSE=''
    else
      PROJECT_CLAUSE="project in (${JIRA_PROJECTS}) and "
    fi

    JQ_QUERY='.issues[]|"\(.key)\t\(.fields.summary)"'
    TRIM=$(tr -d ' ' <<< $LINE)
    CURL=$(curl --location --silent --request POST --header "Authorization: Basic ${JIRA_AUTH}" --header "Content-Type: application/json" ${JIRA_DOMAIN}/rest/api/2/search -d '{"jql":"'"${PROJECT_CLAUSE}"'text ~ \"'"${SEARCH}"'\"", "maxResults":15}')

    if [[ ! $? -eq 0 ]]; then
      echo "Curling [${JIRA_DOMAIN}/rest/api/2/search] has failed; stopping." >&2
      return 1
    fi

    JQ=$(jq -r ${JQ_QUERY} <<< $CURL)

    if [[ ! $? -eq 0 ]]; then
      echo "Parsing the result of curling [${JIRA_DOMAIN}/rest/api/2/search] with jq query [${JQ_QUERY}] has failed; stopping." >&2
      return 1
    fi

    echo -e "$JQ"
    return 0
  fi

  while read -r LINE
  do
    LINE=$(awk '{print $1}' <<< $LINE)

    case "$COMMAND" in
      link|l|open|o)
            ;;
      info|i)
            JQ_QUERY="\"\n\(.fields.summary)\n\nAsignee\n\(.fields.assignee.displayName)\n\nStatus\n\(.fields.status.name)\n\nUpdated\n\(.fields.updated)\n----------------------------------------\""
            ;;
      raw|r)
            CUSTOM_JQ_QUERY="$2"

            if [[ ! -z $CUSTOM_JQ_QUERY ]]; then
              JQ_QUERY="${CUSTOM_JQ_QUERY}"
            else
              JQ_QUERY="."
            fi
            ;;
      title|t)
            JQ_QUERY='.fields.summary'
            ;;
      issuetype)
            JQ_QUERY='.fields.issuetype.name'
            ;;
      project|p)
            JQ_QUERY='.fields.project.name'
            ;;
      created)
            JQ_QUERY='.fields.created'
            ;;
      creator)
            JQ_QUERY='.fields.creator.displayName'
            ;;
      reporter)
            JQ_QUERY='.fields.reporter.displayName'
            ;;
      updated)
            JQ_QUERY='.fields.updated'
            ;;
      assignee|a)
            JQ_QUERY='.fields.assignee.displayName'
            ;;
      status|st)
            JQ_QUERY='.fields.status.name'
            ;;
      *)
            echo "$USAGE" >&2
            return 1
            ;;
    esac

    case "$COMMAND" in
      link|l)
            echo "${JIRA_DOMAIN}/browse/${LINE}"
            ;;

      open|o)
            case "$(uname)" in
              Darwin)
                OPEN=open
                ;;
              *)
                OPEN=xdg-open
                ;;
            esac

            ${OPEN} "${JIRA_DOMAIN}/browse/${LINE}"
            ;;

      *)
            TRIM=$(tr -d ' ' <<< $LINE)
            CURL=$(curl --location --silent --request GET --header "Authorization: Basic ${JIRA_AUTH}" --header "Content-Type: application/json" ${JIRA_DOMAIN}/rest/api/2/issue/${TRIM})

            if [[ ! $? -eq 0 ]]; then
              echo "Curling [${JIRA_DOMAIN}/rest/api/2/issue/${TRIM}] has failed; stopping." >&2
              return 1
            fi

            JQ=$(jq -r ${JQ_QUERY} <<< $CURL)

            if [[ ! $? -eq 0 ]]; then
              echo "Parsing the result of curling [${JIRA_DOMAIN}/rest/api/2/issue/${TRIM}] with jq query [${JQ_QUERY}] has failed; stopping." >&2
              return 1
            fi

            echo -e "$LINE\t$JQ"
            ;;
    esac
  done
}
