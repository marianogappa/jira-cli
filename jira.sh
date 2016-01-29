function jira {

  USAGE='
  Usages:

    echo TIS-1234 | jira [subcommand]
    cat file_with_ticket_names.txt | jira [subcommand]
    jira [subcommand] <<< TIS-1234

  Possible subcommands:

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

  Note that the spaces are significant (I will do {print $3} with awk) and that dXNlcjpwYXNz := base64(user:pass).
  Configuration keys are case sensitive! (e.g. don'\''t do '\''Auth = dXNlcjpwYXNz'\'')
  The BasicAuth credentials are your Jira login credentials.
  '

  if [ ! -f ~/.jiraconfig ]; then
    echo "$NO_CONFIG_FILE" >&2
    return 1
  fi

  if [ $# -eq 0 ]; then
    echo "$USAGE" >&2
    return 1
  else
    COMMAND=$1
  fi

  JIRA_AUTH=$(awk '/^auth/{print $3}' ~/.jiraconfig)
  JIRA_DOMAIN=$(awk '/^domain/{print $3}' ~/.jiraconfig)

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
    case "$COMMAND" in
      link)
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
            echo $USAGE >&2
            return 1
            ;;
    esac

    case "$COMMAND" in
      link)
            echo "${JIRA_DOMAIN}/browse/${LINE}"
            ;;
      *)
            A=$(tr -d ' ' <<< $LINE)
            B=$(curl --silent -X GET -H "Authorization: Basic ${JIRA_AUTH}" -H "Content-Type: application/json" ${JIRA_DOMAIN}/rest/api/2/issue/${A})
            C=$(jq -r ${JQ_QUERY} <<< $B)
            echo "$C"
            ;;
    esac
  done
}
