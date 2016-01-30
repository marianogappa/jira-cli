function jira {

  USAGE='
  Usages:

    echo TIS-1234 | jira [subcommand]
    cat file_with_issue_names.txt | jira [subcommand]
    jira [subcommand] <<< TIS-1234

  Possible subcommands:

      ok          returns either "OK" or e.g. "NOT OK. REST API returned [HTTP/1.1 401 Unauthorized] to a /myself GET request."
      info        returns basic info about an issue: number, title, asignee, status and last update date

      link        returns e.g. -> https://company.atlassian.net/browse/TIS-1234
      title       returns e.g. -> Look for and remove all SQL injections
      issuetype   returns e.g. -> Epic
      project     returns e.g. -> New Website
      created     returns e.g. -> 2016-01-22T10:58:30.162+1300
      creator     returns e.g. -> John Doe
      reporter    returns e.g. -> John Doe
      updated     returns e.g. -> 2016-01-22T10:58:30.162+1300
      assignee    returns e.g. -> John Doe
      status      returns e.g. -> Open
  '

  NO_CONFIG_FILE='
  The Jira Rest API works with BasicAuth. Please create this file: ~/.jiraconfig and put something like this in it:

  auth = dXNlcjpwYXNz
  domain = https://yourdomain.atlassian.net

  - Note that the spaces are significant (I will do {print $3} with awk) and that dXNlcjpwYXNz := base64(user:pass).
  - Configuration keys are case sensitive! (e.g. don'\''t do '\''Auth = dXNlcjpwYXNz'\'')
  - The BasicAuth credentials are your Jira login credentials.
  '

  if [[ ! -f ~/.jiraconfig ]]; then
    echo "$NO_CONFIG_FILE" >&2
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

  while read -r LINE
  do
    # TODO provide a raw jq query
    # TODO provide a raw output
    # Maybe `jira raw` gives the output and `jira raw '.fields'` processes jq queries
    case "$COMMAND" in
      link)
            ;;
      info)
            JQ_QUERY="\"----------------------------------------\n${LINE}\n\(.fields.summary)\n\nAsignee\n\(.fields.assignee.displayName)\n\nStatus\n\(.fields.status.name)\n\nUpdated\n\(.fields.updated)\""
            ;;
      title)
            JQ_QUERY='.fields.summary'
            ;;
      issuetype)
            JQ_QUERY='.fields.issuetype.name'
            ;;
      project)
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
      assignee)
            JQ_QUERY='.fields.assignee.displayName'
            ;;
      status)
            JQ_QUERY='.fields.status.name'
            ;;
      *)
            echo "$USAGE" >&2
            return 1
            ;;
    esac

    case "$COMMAND" in
      link)
            echo "${JIRA_DOMAIN}/browse/${LINE}"
            ;;
      *)
            TRIM=$(tr -d ' ' <<< $LINE)
            CURL=$(curl --location --silent --request GET --header "Authorization: Basic ${JIRA_AUTH}" --header "Content-Type: application/json" ${JIRA_DOMAIN}/rest/api/2/issue/${TRIM})

            if [[ ! $? -eq 0 ]]; then
              echo "Curling ${JIRA_DOMAIN}/rest/api/2/issue/${TRIM} has failed; stopping." >&2
              return 1
            fi

            JQ=$(jq -r ${JQ_QUERY} <<< $CURL)

            if [[ ! $? -eq 0 ]]; then
              echo "Parsing the result of GETting [${JIRA_DOMAIN}/rest/api/2/issue/${TRIM}] with jq query [${JQ_QUERY}] has failed; stopping." >&2
              return 1
            fi

            echo -e "$JQ"
            ;;
    esac
  done
}
