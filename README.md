# Jira CLI
Lightweight bash script for easily querying your company's JIRA issues

## Usage
```
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
```

## Setup

If you don't want to read this, just source the script and run `jira`


1. Clone repo on your workspace `cd ~/workspace && git clone git@github.com:MarianoGappa/jira-cli.git`
2. Source the script `printf '%s' 'source ~/workspace/jira-cli/jira.sh' >> ~/.bashrc`
3. Create a `.jiraconfig` on your home folder `vi ~/.jiraconfig` and add:
```
  auth = dXNlcjpwYXNz    # == base64(user:pass)
  domain = https://yourdomain.atlassian.net
  projects = ABC,DEF     # Optional; used to filter searches
```
  - Note that the spaces are significant (I will do `{print $3}` with `awk`)
  - Configuration keys are case sensitive! (e.g. don't do `Auth = dXNlcjpwYXNz`)
  - The BasicAuth credentials are your Jira login credentials

Done! Check that everything works by running `jira ok`

If you get `HTTP/1.1 401 Unautorized`, your BasicAuth base64 code might be wrong or you may not have access to that account.

## Use case examples

- Search for issues about a billing bug
```
$ jira search 'billing bug'
DEF-1234  Billing doesn't process properly when it rains
DEF-5678  Problem with printing billing reports
```
- Get just the ticket numbers
```
$ jira search 'billing bug' | awk '{print $1}'
DEF-1234
DEF-5678
```
- See if they are closed already or you should still worry
```
$ jira search 'billing bug' | awk '{print $1}' | jira status
Open
Closed
```
- Mmm; the first one is still open. A little more info would be interesting
```
$ jira info <<< DEF-1234
----------------------------------------
DEF-1234
Billing doesn't process properly when it rains

Asignee
John NewGuy

Status
Open

Updated
2015-12-09T17:27:00.525+1300
```
- New guy? Last updated a year ago? Looks like it's time to worry; open both of them in the browser
```
$ jira search 'billing bug' | awk '{print $1}' | jira link | xargs open
** hopefully 2 browser tags open with the JIRA issue pages **
```

## Security concerns

- This script is read-only: it only searches and gets info about JIRA issues
- This script curls a REST API endpoint; if you run it a million times fast you know what may happen
- This script uses BasicAuth over the domain you set on the config; if you configure an http domain you are sending your credentials in plain text through the interwebs. Fortunately, JIRA uses https and curl will not let you go ahead if the certs expire.

## Dependencies

- cURL
- [jq](https://stedolan.github.io/jq/) for parsing JSON
