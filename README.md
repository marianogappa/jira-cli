# Jira CLI
Lightweight bash script for easily querying your company's JIRA issues

## Setup

```
cd ~/workspace && git clone git@github.com:MarianoGappa/jira-cli.git
echo 'source ~/workspace/jira-cli/jira.sh' >> ~/.bashrc
source ~/.bashrc
jira ok
```

- The first time you run it, a config file will be created and opened for you to edit the minimal things to make it work
- If you get `HTTP/1.1 401 Unautorized`, your BasicAuth base64 code might be wrong or you may not have access to that account. Did you use your email instead of your username?

## Use case examples

- Search for issues about a billing bug
```
$ jira search 'billing bug'
DEF-1234  Billing doesn't process properly when it rains
DEF-5678  Problem with printing billing reports
```
- See if they are closed already or you should still worry
```
$ jira search 'billing bug' | jira status
DEF-1234  Closed
DEF-5678  Open
```
- Mmm; the second one is still open. A little more info would be interesting
```
$ jira search 'billing bug' | jira info 2
DEF-5678
The printer is broken like in Office Space (paper jam but no paper jam)

Asignee
John NewGuy

Status
Open

Updated
2015-12-09T17:27:00.525+1300
----------------------------------------
```
- New guy? Last updated a year ago? Looks like it's time to worry; open the second one on the browser
```
$ jira search 'billing bug' | jira open 2
** hopefully a browser tag opens with the JIRA issue page **
```
- For more subcommand options just run:
```
jira
```

## Uninstalling

```
rm ~/.jiraconfig
rm -rf ~/workspace/jira-cli
# and remove source line on ~/.bashrc
```

## Security concerns

- This script is read-only: it only searches and gets info about JIRA issues
- This script curls a REST API endpoint; if you run it a million times fast you know what may happen
- This script uses BasicAuth over the domain you set on the config; if you configure an http domain you are sending your credentials in plain text through the interwebs. Fortunately, JIRA uses https and curl will not let you go ahead if the certs expire.

## Dependencies

- cURL
- [jq](https://stedolan.github.io/jq/) for parsing JSON
