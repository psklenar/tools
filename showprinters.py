#!/usr/bin/python3
#psklenar@redhat.com

import cups
from optparse import OptionParser


def get_options():
    parser = OptionParser(usage="usage: %prog [options]",
                          version="%prog 1.0")
    parser.add_option("--server",
                      dest="server",
                      help="cups local server")
    parser.add_option("--string",
                      dest="string",
                      default="",
                      help="string to parse in name of the queue")
    (options, args) = parser.parse_args()
    return options


class StringQueue(object):

    def __init__(self, server, string):
        self.server = server
        self.stringInName = string
        self.conn =''
        self.list = []

    def queues(self):
        conn = cups.Connection(self.server)
        self.conn = conn.getPrinters()


    def makelist(self):
        for i in self.conn.keys():
            if self.stringInName in i:
                self.list.append(i)

    def printlist(self):
        for i in self.list:
            print(i)

    def end(self):
        if not self.list:
            print('No printers found')
            exit(1)


def main():
    try:
        options = get_options()
        if options.server is None:
            print("cannot connect")
            exit(1)
    except:
        exit(1)
    result = StringQueue(server=options.server, string=options.string)
    result.queues()
    result.makelist()
    result.printlist()
    result.end()


if __name__ == '__main__':
    main()



