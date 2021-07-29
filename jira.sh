#!/bin/bash

function jira {

  USAGE=$(echo -e '
  \033[1;37mUsage\033[0m

    \033[1;37mjira\033[0m [subcommand]


  \033[1;37mUsage examples\033[0m

    \033[1;37mjira search\033[0m "validation enhancements"

    \033[1;37mjira s\033[0m "validation enhancements" | \033[1;37mjira open\033[0m 3

    \033[1;37mjira me\033[0m | \033[1;37mjira o\033[0m

    \033[1;37mjira info\033[0m <<< "ABC-1234"

    cat file_with_issue_names.txt | \033[1;37mjira status\033[0m

    echo "ABC-123,ABC-456,ABC-789" | tr "," "\\n" | \033[1;37mjira title\033[0m

    echo "ABC-123" | \033[1;37mjira raw\033[0m | grep "John Doe"


  \033[1;37mSubcommands\033[0m

    \033[1;37mok\033[0m                 checks if everything is ok, by issuing a /myself
    \033[1;37msearch|s\033[0m [term]    search issues by search term
    \033[1;37mme|m\033[0m               search last updated open issues assigned to me


  \033[1;37mSubcommands that take \\n-separated issues from STDIN\033[0m
  (all these accept an integer e.g. "jira open 2" to filter STDIN to just the ith line)

    \033[1;37mopen|o\033[0m          open an issue on your web browser
    \033[1;37minfo|i\033[0m          basic info about an issue
    \033[1;37mraw\033[0m             pretty print raw JSON /issue output

    \033[1;37mlink|l\033[0m          e.g. \033[1;37m->\033[0m \033[1;32mABC-123   https://company.atlassian.net/browse/ABC-1234\033[0m
    \033[1;37mtitle|t\033[0m         e.g. \033[1;37m->\033[0m \033[1;32mABC-123   Look for and remove all SQL injections\033[0m
    \033[1;37missuetype\033[0m       e.g. \033[1;37m->\033[0m \033[1;32mABC-123   Epic\033[0m
    \033[1;37mproject\033[0m         e.g. \033[1;37m->\033[0m \033[1;32mABC-123   New Website\033[0m
    \033[1;37mstatus|st\033[0m       e.g. \033[1;37m->\033[0m \033[1;32mABC-123   Open\033[0m

    \033[1;37mcreated\033[0m         e.g. \033[1;37m->\033[0m \033[1;32mABC-123   2016-01-22T10:58:30.162+1300\033[0m
    \033[1;37mupdated\033[0m         e.g. \033[1;37m->\033[0m \033[1;32mABC-123   2016-01-22T10:58:30.162+1300\033[0m

    \033[1;37mcreator\033[0m         e.g. \033[1;37m->\033[0m \033[1;32mABC-123   John Doe\033[0m
    \033[1;37mreporter\033[0m        e.g. \033[1;37m->\033[0m \033[1;32mABC-123   John Doe\033[0m
    \033[1;37massignee|a\033[0m      e.g. \033[1;37m->\033[0m \033[1;32mABC-123   John Doe\033[0m
  ')

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
		# If you want to use this feature, please uncomment it:
		#
		#projects = ABC,DEF


		# The 'jira me' command lists the top 15 issues that are of interest to you.
		#
		# By default, it will yield the top 15 last updated issues that are assigned
		# to you and are still open. You are welcome to replace this functionality
		# with your own customised JQL script, but note that you must escape double
		# quotes.
		#
		# Default value:
		#
		# me-filter = 'assignee = currentUser() AND status in (Open, \"To Do\", \"In Progress\", Reopened) ORDER BY updated DESC'
		#
		me-filter = "assignee = currentUser() AND status in (Open, \"To Do\", \"In Progress\", Reopened) ORDER BY updated DESC"
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
  ME_FILTER=$(grep '^me-filter = ' ~/.jiraconfig | sed 's/me-filter = "\(.*\)"/\1/')

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

    if [[ "$CURL" == "HTTP/1.1 200" ]]; then
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
    CURL=$(curl --location --silent --request POST --header "Authorization: Basic ${JIRA_AUTH}" --header "Content-Type: application/json" ${JIRA_DOMAIN}/rest/api/2/search -d '{"jql":"'"${PROJECT_CLAUSE}"'text ~ \"'"${SEARCH}"'\" ORDER BY updated DESC", "maxResults":15}')

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

  # Many people (like me) would prefer to see the latest issues on their "Activity Stream"
  # If you are one of these people, please go complain on this JIRA issue opened in 2003 and still actively neglected
  # as of January, 2016:
  #
  # https://jira.atlassian.com/browse/JRA-1973
  #
  if [[ $COMMAND == "me" ]] || [[ $COMMAND == "m" ]]; then
    if [[ -z $ME_FILTER ]]; then
      JQL="assignee = currentUser() AND status in (Open, \\\"To Do\\\", \\\"In Progress\\\", Reopened) ORDER BY updated DESC"
    else
      JQL="${ME_FILTER}"
    fi

    JQ_QUERY='.issues[]|"\(.key)\t\(.fields.summary)"'
    CURL=$(curl --location --silent --request POST --header "Authorization: Basic ${JIRA_AUTH}" --header "Content-Type: application/json" ${JIRA_DOMAIN}/rest/api/2/search -d '{"jql":"'"${JQL}"'", "maxResults":15}')

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

  I=0
  while read -r LINE
  do
    I=$((I+1))
    NUMBER=$2

    if [[ -z $NUMBER ]] || [[ $NUMBER -eq $I ]]; then
      LINE=$(awk '{print $1}' <<< $LINE)

      case "$COMMAND" in
        link|l|open|o)
              ;;
        info|i)
              JQ_QUERY="\"\n\(.fields.summary)\n\nAsignee\n\(.fields.assignee.displayName)\n\nStatus\n\(.fields.status.name)\n\nUpdated\n\(.fields.updated)\n----------------------------------------\""
              ;;
        raw|r)
              JQ_QUERY="."
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

              if [[ $COMMAND == "raw" ]] || [[ $COMMAND == "r" ]] ; then
                echo -e "$JQ"
              else
                echo -e "$LINE\t$JQ"
              fi
              ;;
      esac

    fi
  done
}
