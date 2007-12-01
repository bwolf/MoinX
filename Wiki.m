/* $Id: Wiki.m 19 2005-02-20 20:55:03Z bwolf $
 *
 * Copyright 2005 Marcus Geiger
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
#import <unistd.h>
#import <signal.h>
#import <stdlib.h>
#import "Wiki.h"
#import "Archiver.h"

static NSString *MOINX_STORAGE = @"Library/Application Support/MoinX";
static NSString *MOINX_INSTANCE = @"instance";
static NSString *TWISTD_START_SCRIPT = @"twistd";
static NSString *BUNDLE_PYTHON_LIB_AUX_DIR = @"pythonlib-aux";
static NSString *BUNDLE_PYTHON_LIBZIP = @"pythonlib.zip";
static NSString *BUNDLE_HTDOCS = @"htdocs";
static NSString *BUNDLE_INSTANCE_TEMPLATE = @"instance.tar.bz2";

// Signal handler SIGUSR1; wiki notifies us on startup
static volatile BOOL parentFired = FALSE;

static void sig_usr1(int signo)
{
    if (signo == SIGUSR1)
    {
        parentFired = TRUE;
    }
}

@implementation Wiki

+ (void)initialize
{
    //NSLog(@"initialize");

    if (signal(SIGUSR1, sig_usr1) == SIG_ERR)
    {
        NSLog(@"failed to register signal handler");
        exit(1);
    }
}

- (id)initWithBundle:(NSBundle *)aBundle model:(WikiModel *)wikiModel
{
    //NSLog(@"init");
    NSAssert(aBundle != nil, @"aBundle must not be nil");

    [super init];
    bundle = [aBundle retain];
    model = [wikiModel retain];

    return self;
}

- (void)dealloc
{
    //NSLog(@"dealloc");
    [bundle release];
    [model release];
    [super dealloc];
}

- (id)delegate
{
    return delegate;
}

- (void)setDelegate:(id)aObject
{
    //NSLog(@"setDelegate: %@", aObject);
    delegate = aObject;
}

- (NSString *)instanceDirectory
{
    NSString *instanceDir =
        [[NSHomeDirectory() stringByAppendingPathComponent:MOINX_STORAGE]
            stringByAppendingPathComponent:MOINX_INSTANCE];

    return instanceDir;
}

- (NSString *)_lazyCreateWikiInstance
{
    NSFileManager *manager = [NSFileManager defaultManager];

    // Create wiki instance if none exists there by checking if
    // ~/Library/Application Support/MoinX/instance
    // exists.
    NSString *instanceTemplate = [[bundle resourcePath]
        stringByAppendingPathComponent:BUNDLE_INSTANCE_TEMPLATE];
    NSString *storageBaseDir =
        [NSHomeDirectory() stringByAppendingPathComponent:MOINX_STORAGE];
    [manager createDirectoryAtPath:storageBaseDir attributes:nil];
    NSString *storageDir = [storageBaseDir
        stringByAppendingPathComponent:MOINX_INSTANCE];

    if (![manager fileExistsAtPath:storageDir])
    {
        Archiver *archiver = [[[Archiver alloc]
            initWithWorkingDirectory:storageBaseDir] autorelease];

        if ([archiver extract:instanceTemplate])
        {
            NSLog(@"Successfully extracted instance at %@", storageDir);
        }
        else
        {
            NSRunAlertPanel(nil,
                [archiver errorString],
                NSLocalizedString(@"OK", @"OK"), nil, nil);
            return nil;
        }
    }
    
    // Finally symlink 'startmoin.py' and 'wikiconfig.py' from the pyrun dir
    // to ~/Libaray/Application Support/MoinX/instance
    NSString *starterPyAtBundle = [[[bundle resourcePath]
        stringByAppendingPathComponent:@"pyrun"]
        stringByAppendingPathComponent:@"startmoin.py"];
    NSString *configPyAtBundle = [[[bundle resourcePath]
        stringByAppendingPathComponent:@"pyrun"]
        stringByAppendingPathComponent:@"wikiconfig.py"];
    
    NSString *starterPyAtStorage = [storageDir
        stringByAppendingPathComponent:@"startmoin.py"];
    NSString *configPyAtStorage = [storageDir
        stringByAppendingPathComponent:@"wikiconfig.py"];
    
    // Unlink the destination files, ignoring errors.
    unlink([starterPyAtStorage UTF8String]);
    unlink([configPyAtStorage UTF8String]);
    
    // Symlink from bundle to instance directory.
    if (symlink([starterPyAtBundle UTF8String], [starterPyAtStorage UTF8String]) != 0)
    {
        NSLog(@"ERROR: Can't symlink %@ to %@ because: %s",
              starterPyAtBundle, starterPyAtStorage, strerror(errno));
        exit(1);
    }

    if (symlink([configPyAtBundle UTF8String], [configPyAtStorage UTF8String]) != 0)
    {
        NSLog(@"ERROR: Can't symlink %@ to %@ because: %s",
              starterPyAtBundle, starterPyAtStorage, strerror(errno));
        exit(1);
    }

    return [[storageDir retain] autorelease];
}

- (void)start
{
    //NSLog(@"start");

    if ([self isRunning])
    {
        NSLog(@"ERROR: already running");
        return;
    }

    // Set our timer for changing the statusitem's name when the timer fires and the child
    // process notified us by signaling a SIGUSR1.
    childPollTimer = [[NSTimer scheduledTimerWithTimeInterval:1.0 target:self
        selector:@selector(_timer:)
        userInfo:nil repeats:YES]
        retain];

    // Create wiki instance if needed
    NSString *storageDir = [self _lazyCreateWikiInstance];
    if (storageDir == nil)
        return;

    // Prepare resources needed for launching MoinMoin with twistd: 
    // MoinMoin static htdocs directory, python library directory, twisted
    // script 'twistd'
    NSString *moinHtdocs =  [[bundle resourcePath]
        stringByAppendingPathComponent:BUNDLE_HTDOCS];
	
    NSString *pythonLibZip = [[bundle resourcePath]
        stringByAppendingPathComponent:BUNDLE_PYTHON_LIBZIP];
	NSString *pythonLibAux = [[bundle resourcePath]
		stringByAppendingPathComponent:BUNDLE_PYTHON_LIB_AUX_DIR];
    
	NSString *twistd = [bundle pathForResource:TWISTD_START_SCRIPT
        ofType:nil inDirectory:@"bin"];

    if (pythonLibZip && pythonLibAux && twistd)
    {
		NSString *pythonPathValue =
			[NSString stringWithFormat:@"%@:%@", pythonLibZip, pythonLibAux];
		
        NSArray *args = [NSArray arrayWithObjects:
            @"--quiet",
            @"--nodaemon",
            @"--python=startmoin.py",
            nil];

        NSMutableDictionary *env = [model moinxStartupEnvironment];
        [env setObject:pythonPathValue forKey:@"PYTHONPATH"];
        [env setObject:moinHtdocs forKey:@"MOINX_HTDOCS"];

        // Setup NSTask
        task = [[NSTask alloc] init];
        [task setCurrentDirectoryPath:storageDir];
        [task setLaunchPath:twistd];
        [task setArguments:args];
        [task setEnvironment:env];

        //NSLog(@"Launching NSTask (twistd)");
        [task launch];
    }

    if ([model bonjour])
    {
        //NSLog(@"announcing with bonjour");
        service = [[NSNetService alloc]
            initWithDomain:@"" // default domain
            type:@"_http._tcp."
            name:[model featureForKey:@"sitename"]
            port:[model listenPort]];
        [service publish];
    }
}

- (void)stop
{
    //NSLog(@"stop");
    int exitStatus = 0;

    if (![self isRunning])
    {
        NSLog(@"ERROR: not running");
    }
    else
    {
        [task terminate];
        if (service)
        {
            [service stop];
            [service release];
            service = nil;
        }

        // Timer cleanup, should never happen here
        if (childPollTimer != nil)
        {
            [childPollTimer invalidate];
            [childPollTimer release];
            childPollTimer = nil;
        }

        // Wait for the task to terminate
        [task waitUntilExit];
        exitStatus = [task terminationStatus];
        [task release];
        task = nil;

        //NSLog(@"wiki task terminated with exit status %D", exitStatus);       
        if (delegate && [delegate respondsToSelector:@selector(wikiStopped:)])
        {
            //NSLog(@"invoking selector (wikiStopped:) on delegate");
            NSNumber *status = [NSNumber numberWithInt:exitStatus];
            [delegate performSelector:@selector(wikiStopped:) withObject:status];
        }
        else
        {
            NSLog(@"Delegate doesn't understand selector (wikiStopped:)");
        }
    }
}

- (void)restart
{
    [self stop];
    [self start];
}

- (BOOL)isRunning
{
    //NSLog(@"isRunning");

    return task != nil && [task isRunning];
}

- (void)_timer:(NSTimer *)aTimer
{
    //NSLog(@"Timer fired");
    if (aTimer == childPollTimer && parentFired)
    {
        //NSLog(@"child notified us");
        [childPollTimer invalidate];
        [childPollTimer release];
        childPollTimer = nil;

        // Notify delegate that the wiki is running
        if (delegate)
        {
            if ([delegate respondsToSelector:@selector(wikiStarted)])
            {
                //NSLog(@"invoking selector (wikiStarted) on delegate");
                [delegate performSelector:@selector(wikiStarted)];
            }
            else
            {
                NSLog(@"Delegate doesn't understand selector (wikiStarted)");
            }
        }
    }
}

@end
