#!/usr/bin/env python
# Author Petr Sklenar psklenar@gmail.com
# script adds comment to github pull request
# EXAMPLE:
#       python github_comments.py --pullrequest 12 -o container-images -r memcached -t your_token -c "your comment"



import requests
import json

from optparse import OptionParser

def options():
    global options
    parser = OptionParser(usage="usage: %prog [options]",
                          version="%prog 1.0")
    parser.add_option("-p", "--pullrequest",
                      action="store",
                      dest="pullRequest",
                      default=False,
                      help="pull request where to write comments")
    parser.add_option("-t", "--token",
                      action="store",
                      dest="token",
                      default=False,
                      help="your secret token")
    parser.add_option("-o", "--githubOrgName",
                      action="store",
                      dest="githubOrgName",
                      default=False,
                      help="name of the organization / username , for ex:\n"
                           "https://github.com/'STRING_NEED'.git where STRING_NEED='org_user/reponame'")
    parser.add_option("-r", "--githubRepoName",
                      action="store",
                      dest="githubRepoName",
                      default=False,
                      help="name of the repo, for ex:\n"
                           "https://github.com/'STRING_NEED'.git where STRING_NEED='org_user/reponame'")
    parser.add_option("-l", "--list",
                      action="store_true", # optional because action defaults to "store"
                      dest="list",
                      default=False,
                      help="show all stuff for selected pull request")
    parser.add_option("-c", "--comment",
                      action="store", # optional because action defaults to "store"
                      dest="comment",
                      default=False,
                      help="comment it")
    (options, args) = parser.parse_args()

    if not (options.pullRequest):
        parser.error("Pull request not given")

    if not (options.githubOrgName):
        parser.error("Org Name not given")

    if not (options.githubRepoName):
        parser.error("Repo Name not given")

    if not any((options.token)):
        print("WARN: --token not found, its good for Authenticated requests get a higher rate limit\n")

    if not any((options.list, options.comment)):
        parser.error("Action needed, --list or --comment")

    return options

def header():
    return {
    'Content-Type': 'application/json',
    'Authorization': 'token {0}'.format(options.token),
}

def list_sha():
    headers = header()
    url="https://api.github.com/repos/{0}/{1}/pulls/{2}/commits".format(options.githubOrgName, options.githubRepoName, options.pullRequest)
    r = requests.get(url,headers=headers)
    #print r.json()
    for item in r.json():
        return item['sha']

def save(sha):
    headers = header()
    url="https://api.github.com/repos/{0}/{1}/commits/{2}/comments".format(options.githubOrgName, options.githubRepoName, sha)
    data1 = {
        'body' : '{0}'.format(options.comment)
}
    data = json.dumps(data1)
    r = requests.post(url , headers=headers, data=data)
    if r.status_code == 201:
        return True
    else:
        raise Exception('http return code is bad', r.status_code)
        return False



def main():
    options()
    if options.list:
        print "searching for sha"
        print list_sha()
    if options.comment:
        sha = list_sha()
        print "save results"
        if save(sha):
            print "OK"
        else:
            print "error"

if __name__ == '__main__':
    main()

