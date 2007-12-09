"""
        twisted.web based wiki server

        Run this server with mointwisted script on Linux or Mac OS X, or
        mointwisted.cmd on Windows.

        @copyright: 2004 Thomas Waldmann, Oliver Graf, Nir Soffer
        @license: GNU GPL, see COPYING for details.

        @copyright: 2005-2006 Marcus Geiger
        $Id$
"""
import sys
sys.path.insert(0, '.')

import os
import threading
import signal
import errno

from MoinMoin.server.twistedmoin import TwistedConfig, makeApp

class Config(TwistedConfig):
        docs = os.environ['MOINX_HTDOCS']
        user = None
        group = None
        port = int(os.environ['MOINX_LISTEN_PORT'])
        interfaces = os.environ['MOINX_LISTEN_IP'].split(':')
        threads = 10
        logPath = None #'mointwisted.log'
        logPath_twisted = None

class MoinXParentMonitor(threading.Thread):
        """Monitor thread to exit the process if the parent dies.
           Author: Marcus Geiger.
        """
        SLEEP_TIMEOUT = 5 # in seconds

        def __init__(self):
                threading.Thread.__init__(self)
                self.__parentPid = os.getppid()
                if self.__parentPid == 1:
                        # Our parent already died, so init is our parent, stop here
                        raise StandardError, "Our parent died; Can't continue"
                #print 'Checking if parent %u is alive' % self.__parentPid
                # if no error, then our parent is alive
                os.kill(self.__parentPid, 0)
                print 'Monitoring parent process id: %u' % self.__parentPid
                self.__event = threading.Event()

        def notifyParent(self):
                """Parent should catch SIGUSR1 to update the menu status."""
                #print 'notifing parent %u' % self.__parentPid
                os.kill(self.__parentPid, signal.SIGUSR1)

        def run(self):
                #print 'in thread.run'
                while True:
                        #print 'Timer exceed'
                        self.__event.wait(MoinXParentMonitor.SLEEP_TIMEOUT)
                        self.monitor()
                        self.__event.clear() # for safety
                print 'exiting thread.run'

        def monitor(self):
                import os, signal
                ppid = os.getppid()
                if ppid != self.__parentPid:
                        print 'ppid changed to %u; killing myself' % ppid
                        pgrp = os.getpgrp()
                        print 'killing process group %u' % pgrp
                        os.kill(pgrp, signal.SIGTERM)

# Monitor parent process in a separate thread
def moinXStartParentMonitor():
        """Actually start a MoinXParentMonitor thread."""
        monitor = MoinXParentMonitor()
        monitor.setDaemon(True)
        monitor.start()
        monitor.notifyParent()

# To print the environment enable this
def moinXDumpEnvironment():
        k = os.environ.keys()
        k.sort()
        for x in k:
                print u'%s:%s' % (x, os.environ[x])

# Startup 
#moinXDumpEnvironment()
moinXStartParentMonitor()
application = makeApp(Config)
