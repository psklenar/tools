#!/usr/bin/env python
# Author Petr Sklenar psklenar@gmail.com
# script adds comment to github pull request
# EXAMPLE:
#
# 1, store comment:
#./github_comments.py -t YOURGITHUBTOKEN -o psklenar -r tools -p 2 -a store -s 0 -c "abc" -R "Moje CI" -u https://example.org
#
# 2, store as pull request status:
# for status you have to use proper status codes `0` is success, `1` is failure, `2` is error, `3` is pending
#
#./github_comments.py -t YOURGITHUBTOKEN -o psklenar -r tools -p 2 -a store -s 0 -c "abc" -R "Moje CI" -u https://example.org -w status
#
#
# SEND EMAIL:
#EMAIL_FROM=user@example.com
#EMAIL_SERVER=mail.example.com
#EMAIL=user@example.com
#./github_comments.py -t YOURGITHUBTOKEN -o psklenar -r tools -p 2 -a store -s 0 -c "abc" -R "Moje CI" -u https://example.org  -w email




import requests
import json
import os
import smtplib
from email.mime.text import MIMEText

from optparse import OptionParser

state_translation = ["success", "failure", "error", "pending"]

def get_options():
    parser = OptionParser(usage="usage: %prog [options]",
                          version="%prog 1.0")
    parser.add_option("-p", "--pullrequest",
                      dest="pullRequest",
                      help="pull request where to write comments")
    parser.add_option("-t", "--token",
                      action="store",
                      dest="token",
                      help="your secret token")
    parser.add_option("-o", "--githubOrgName",
                      dest="githubOrgName",
                      help="name of the organization / username , for ex:\n"
                           "https://github.com/'STRING_NEED'.git where STRING_NEED='org_user/reponame'")
    parser.add_option("-r", "--githubRepoName",
                      dest="githubRepoName",
                      help="name of the repo, for ex:\n"
                           "https://github.com/'STRING_NEED'.git where STRING_NEED='org_user/reponame'")
    parser.add_option("-a", "--action",
                      dest="action",
                      choices=["list", "store"],
                      default="list",
                      help="show all stuff for selected pull request")
    parser.add_option("-c", "--comment",
                      dest="comment",
                      default="",
                      help="comment it")
    parser.add_option("-s", "--status",
                      action="store",  # optional because action defaults to "store"
                      dest="status",
                      help="which state to store")
    parser.add_option("-w", "--what",
                      dest="what",
                      action="append",
                      choices=["comment", "status", "email"],
                      default=[],
                      help="how to store result")
    parser.add_option("-R", "--resulttype",
                      dest="type",
                      default="CI",
                      help="context of CI to change")
    parser.add_option("-u", "--url",
                      action="store",  # optional because action defaults to "store"
                      dest="url",
                      default="",
                      help="Result URL with reslts")
    (options, args) = parser.parse_args()

    if not options.token:
        parser.error("Token not given")

    if not options.pullRequest:
        parser.error("Pull request not given")

    if not options.githubOrgName:
        parser.error("Org Name not given")

    if not options.githubRepoName:
        parser.error("Repo Name not given")

    return options

# "error", "failure", "pending", "success"

class GhComment(object):
    def __init__(self, token, orgname, pr, repo):
        self.orgname = orgname,
        self.pr = pr
        self.repo = repo
        self.get_url = "https://api.github.com/repos/{0}/{1}/pulls/{2}".format(orgname, repo, pr)
        self.auth_header = {
                'Content-Type': 'application/json',
                'Authorization': 'token {0}'.format(token),
            }
        self.post_url_type = "comments_url"

    def report_url(self):
        return self.get()[self.post_url_type]

    def get(self):
        r = requests.get(self.get_url, self.auth_header)
        return r.json()

    def post(self):
        r = requests.post(self.report_url(), headers=self.auth_header, data=json.dumps(self.data))
        if r.status_code == 201:
            return True
        else:
            raise Exception('http return code is bad', r.status_code)

    def set_content(self,status ,comment, url , type):
        body = """## {context} comment
* Status: __{status}__
* Result url: __[{url}]({url})__
* Comment: __{comment}__
""".format(status=status, context=type, url=url, comment=comment)

        data = {
            'body': '{body}'.format(body=body)
        }
        self.data = data

class GhStatus(GhComment):
    def __init__(self, *args, **kwargs):
        super(GhStatus,self).__init__(*args, **kwargs)
        self.post_url_type = "statuses_url"

    def set_content(self, status, comment, url, type):
        data = {
            "state": state_translation[status],
            "target_url": url,
            "description": comment,
            "context": type
        }
        self.data = data

class Email(GhComment):
    def __init__(self, *args, **kwargs):
        super(Email,self).__init__(*args, **kwargs)

    def set_content(self, status, comment, url, type):
        self.email_to = os.environ.get("EMAIL")
        self.email_from = os.environ.get("EMAIL_FROM") or "root@localhost"
        self.email_server = os.environ.get("EMAIL_SERVER") or "localhost"
        self.subject = "Automation: {type} for {repo} - {pr}".format(type=type, repo=self.repo, pr=self.pr)
        data = """
Hello,
I'm your CI
Here are results:
----------------

Status:     {status}
Result url: {url}
Comment:    {comment}

      Regards
      Your {type}
""".format(status=status, type=type, url=url, comment=comment)
        self.data = data

    def post(self):
        msg = MIMEText(self.data)
        msg['Subject'] = self.subject
        msg['From'] = self.email_from
        msg['To'] = self.email_to
        server = smtplib.SMTP(self.email_server)
        server.sendmail(self.email_from, [self.email_to], msg.as_string())
        server.quit()


def main():
    options=get_options()
    resobj = None
    for what in options.what:
        if what == "comment":
            print "Store to GitHub Comment"
            resobj = GhComment(token=options.token, orgname=options.githubOrgName, pr=options.pullRequest,
                               repo=options.githubRepoName)
        elif what == "status":
            print "Store to GitHub PR Status"
            resobj = GhStatus(token=options.token, orgname=options.githubOrgName, pr=options.pullRequest,
                               repo=options.githubRepoName)
        elif what == "email":
            print "Send email"
            resobj = Email(token=options.token, orgname=options.githubOrgName, pr=options.pullRequest,
                               repo=options.githubRepoName)
        if options.action == "list":
            print "Items in PR"
            print resobj.get()
        else:
            resobj.set_content(status=int(options.status), comment=options.comment, url=options.url, type=options.type)
            resobj.post()


if __name__ == '__main__':
    main()

