# tools
useful tools

## examples:

* store comment:
```
./github_comments.py -t YOURGITHUBTOKEN -o jscotka -r memcached -p 1 -a store -s 0 -c "abc" -R "Moje CI" -u https://example.org
```

* store as pull request status:
 * for status you have to use proper status codes `0` is success, `1` is failure, `2` is error, `3` is pending
```
./github_comments.py -t YOURGITHUBTOKEN -o jscotka -r memcached -p 1 -a store -s 0 -c "abc" -R "Moje CI" -u https://example.org -w status
```

* send email:
```
EMAIL_FROM=user@example.com
EMAIL_SERVER=mail.example.com
EMAIL=user@example.com
./github_comments.py -t YOURGITHUBTOKEN -o jscotka -r memcached -p 1 -a store -s 0 -c "abc" -R "Moje CI" -u https://example.org  -w email

```

