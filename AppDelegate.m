/* $Id: AppDelegate.m 15 2005-02-14 19:05:47Z bwolf $
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

#import <sys/types.h>
#import <unistd.h>
#import <utime.h>
#import "AppDelegate.h"
#import "WikiModel.h"
#import "Archiver.h"

// UI stuff
static NSString *BUNDLE_MOINX_STATUS_ICON = @"MoinX_statusmenuicon.tif";

// URIs
static NSString *MOINX_VERSION_CHECK_URI = @"http://moinx.antbear.org/versioncheck.xml";
static NSString *MOINX_VERSION_CHECK_KEY = @"LatestVersion";
static NSString *MOINX_VERSION_DOWNLOAD_URI_KEY = @"LatestVersionDownloadURI";

@implementation AppDelegate

- (id)init
{
    //NSLog(@"init");
    [super init];

    // Create wiki instance and set the delegate
    model = [[WikiModel alloc] init];
    [model setDelegate:self];

    // Modify App's bundle/plist's LSUIEelent: right we modify ourself ;-)
    // The LSUIElement in the Info.plist is modified according:
    //
    // THIS MUST HAPPEN HERE !
    //
    // DISPLAY_DOCK             => LSUIElement 0
    // DISPLAY_MENUBAR          => LSUIElement 1
    // DISPLAY_MENUBAR_AND_DOCK => LSUIElement 0
    BOOL restart = FALSE;
    NSString *path = [[[NSBundle mainBundle] bundlePath]
        stringByAppendingString:@"/Contents/Info.plist"];
    NSMutableDictionary *dict = [[[NSMutableDictionary alloc]
        initWithContentsOfFile:path] autorelease];

    // Paranoid
    if (dict == nil)
    {
        dict = [NSMutableDictionary dictionary];
    }

    if ([model display] == DISPLAY_MENUBAR)
    {
        if ((![[dict objectForKey:@"LSUIElement"] isEqualToString:@"1"])
            && [[NSFileManager defaultManager] isWritableFileAtPath:path])
        {
            [dict setObject:@"1" forKey:@"LSUIElement"];
            if (![dict writeToFile:path atomically:YES])
            {
                // @TODO add NSRunAlertPanel
                NSLog(@"DEBUG: Couldn't write Info.plist.");
                exit(0);
            }

            // Change the bundle's modification time to let LaunchServices
            // know we've changed something.
            if (utime([[[NSBundle mainBundle] bundlePath] cString], nil) == -1)
            {
                // @TODO add NSRunAlertPanel
                NSLog(@"DEBUG: utime on bundlePath failed.");
                exit(0);
            }

            restart = TRUE;
        }
    }
    else
    {
        if ((![[dict objectForKey:@"LSUIElement"] isEqualToString:@"0"])
            && [dict objectForKey:@"LSUIElement"])
        {
            [dict setObject:@"0" forKey:@"LSUIElement"];
            [dict writeToFile:path atomically:YES];

            // Change the bundle's modification time to let LaunchServices know we've
            // changed something.
            if (utime([[[NSBundle mainBundle] bundlePath] cString], nil) == -1)
            {
                // @TODO add NSRunAlertPanel
                NSLog(@"DEBUG: utime on bundlePath failed.");
            }

            restart = TRUE;
        }
    }

    if (restart == YES)
    {
        NSLog(@"Restarting myself");
        NSTask *task = [[NSTask alloc] init];
        [task setLaunchPath:@"/usr/bin/open"];
        NSArray *args = [NSArray arrayWithObject:[[NSBundle mainBundle] bundlePath]];
        NSLog(@"Args: %@", args);
        [task setArguments:args];
        [task launch];
        exit(0);
    }

    if ([model checkForUpdates])
    {
        [self checkForUpdates:nil];
    }

    wiki = [[Wiki alloc] initWithBundle:[NSBundle mainBundle] model:model];
    [wiki setDelegate:self];

    return self;
}

- (void)dealloc
{
    //NSLog(@"dealloc");
    [model release];
    [wiki release];
    if (preferenceController)
        [preferenceController release];
    [super dealloc];
}

// Wiki delegate method
- (void)wikiStarted
{
    //NSLog(@"wikiStarted");
    [self setStatus:TRUE];
}

// Wiki delegate method
- (void)wikiStopped:(NSNumber *)exitStatus
{
    //NSLog(@"wikiStopped:exitStatus %@", exitStatus);
    [self setStatus:FALSE];
}

// WikiModel delegate method
- (void)wikiNeedsToBeRestarted
{
    //NSLog(@"wikiNeedsToBeRestarted");
    int res = NSRunAlertPanel(NSLocalizedString(@"WikiRestart", "Restart Wiki"),
        NSLocalizedString(@"WikiNeedsToBeRestarted",
                          @"You changed the MoinX configuration in such a way, "
                          @"that requires the Wiki engine to be restarted.\n\n"
                          @"Should the Wiki engine be restarted?"),
        NSLocalizedString(@"Yes", @"Yes"),
        NSLocalizedString(@"No", @"No"), nil);

    if (res == YES)
    {
        NSLog(@"Restarting wiki engine upon user request");
        [wiki restart];
    }
}

- (void)awakeFromNib
{
    //NSLog(@"awakeFromNib");
    NSBundle *bundle = [NSBundle mainBundle];

    // Initialize the status item
    if ([model display] != DISPLAY_DOCK)
    {
        NSStatusBar* bar = [NSStatusBar systemStatusBar];
        statusItem = [[bar statusItemWithLength:NSVariableStatusItemLength] retain];
        [statusItem setMenu:statusMenu];
        [statusItem setToolTip:@"MoinX Desktop Wiki"];

        // Load the icon
        NSImage *icon = [[NSImage alloc] init];
        NSString *iconPath = [[bundle resourcePath]
            stringByAppendingPathComponent:BUNDLE_MOINX_STATUS_ICON];

        if ([icon initWithContentsOfFile:iconPath])
        {
            [statusItem setImage:icon];
        }
        else
        {
            [statusItem setTitle:@"m"];
            NSAssert(FALSE, @"Can't load status icon");
        }

        [statusItem setHighlightMode:YES];
        [self setStatus:FALSE];
    }
    [self setStatus:TRUE];  // @TODO remove in official build
    [wiki start];
}

- (void)applicationWillTerminate:(NSNotification*)aNotification
{
    //NSLog(@"applicationWillTerminate");
    if ([wiki isRunning])
    {
        //NSLog(@"Stopping wiki");
        [wiki stop];
    }
}

- (void)setStatus:(BOOL)status
{
    if (status)
    {
        [statusItem setEnabled:TRUE];
    }
    else
    {
        [statusItem setEnabled:FALSE];
    }
}

- (IBAction)goToHomepage:(id)sender
{
    //NSLog(@"goToHomepage");
    NSString *host = nil;

    if ([model listenType] == LISTEN_TYPE_LOCAL
        || [model listenType] == LISTEN_TYPE_ALL)
    {
        host = @"localhost";
    }
    else if ([model listenType] == LISTEN_TYPE_SPECIFIC)
    {
        host = [model listenIP];
    }
    else
    {
        NSAssert(FALSE, @"unknown listen type in goToHomepage");
    }

    NSString *url = [NSString stringWithFormat:@"http://%@:%D/", host,
        [model listenPort]];
    //NSLog(@"navigating default browser to: %@", url);
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:url]];
}

- (IBAction)showPreferencePanel:(id)sender
{
    //NSLog(@"showPreferencePanel");
    if (!preferenceController)
    {
        preferenceController = [[PreferenceController alloc] initWithModel:model];
    }
    [preferenceController showWindow:self];
	[[preferenceController window] makeKeyAndOrderFront:self];	
	[NSApp activateIgnoringOtherApps: YES];

}

- (IBAction)export:(id)sender
{
    //NSLog(@"export"); 
    NSString *workingDirecotry = [wiki instanceDirectory];
    NSString *subDir = @"data";

    NSSavePanel *panel = [NSSavePanel savePanel];
    [panel setTitle:NSLocalizedString(@"DataExport", @"Export")];
    [panel setPrompt:NSLocalizedString(@"ExportButton", @"Export")];
    [panel setAllowedFileTypes:[NSArray arrayWithObjects:@"tgz", nil]];
    [panel setRequiredFileType:@"tgz"];
    [panel setAllowsOtherFileTypes:FALSE];
    [panel setDirectory:NSHomeDirectory()];
    [panel setCanCreateDirectories:TRUE];
    [panel setCanSelectHiddenExtension:TRUE];

	[panel setBecomesKeyOnlyIfNeeded:TRUE];
	[[NSApplication sharedApplication] activateIgnoringOtherApps:YES];

    if ([panel runModal] == NSFileHandlingPanelOKButton)
    {
        //NSLog(@"Ok: %@", [panel filename]);
        Archiver *archiver =
            [[[Archiver alloc] initWithWorkingDirectory:workingDirecotry]
                autorelease];
        [archiver create:[panel filename] fromSubDirectory:subDir];

        NSRunAlertPanel(
            NSLocalizedString(@"ExportSucceeded", @"Export succeeded"),
            NSLocalizedString(@"ExportNotifyMsg",
                              @"Your Wiki pages have been successfully exported "
                              @"to the file %@"),
            NSLocalizedString(@"OK", @"OK"), nil, nil, [panel filename]);
    }
    else
    {
        NSLog(@"Cancel export");
    }
}

static void moveFileToUserTrash(NSString *filePath)
{
	NSLog(@"Moving %@ to trash", filePath);
	
    CFURLRef        trashURL;
    FSRef           trashFolderRef;
    CFStringRef     trashPath;
    OSErr           err;
    NSFileManager   *mgr = [NSFileManager defaultManager];
	
    err = FSFindFolder(kUserDomain, kTrashFolderType, kDontCreateFolder, &trashFolderRef);
    if (err == noErr)
	{
		trashURL = CFURLCreateFromFSRef(kCFAllocatorSystemDefault, &trashFolderRef);
		if (trashURL)
		{
			trashPath = CFURLCopyFileSystemPath (trashURL, kCFURLPOSIXPathStyle);
			if (![mgr movePath:filePath 
						toPath:[(NSString *) trashPath
								stringByAppendingPathComponent:[filePath lastPathComponent]] 
					   handler:nil])
			{
				NSLog(@"Could not move %@ to trash", filePath);
			}
        }
        if (trashPath) 
		{
            CFRelease(trashPath);
        }
        CFRelease(trashURL);
    }
}

- (IBAction)import:(id)sender
{
    //NSLog(@"import");
    NSString *workingDirectory = [wiki instanceDirectory];
	NSString *subDir = @"data";

    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setTitle:NSLocalizedString(@"DataImport", @"DataImport")];
    [panel setPrompt:NSLocalizedString(@"ImportButton", @"ImportButton")];
    [panel setAllowedFileTypes:[NSArray arrayWithObjects:@"tgz", nil]];
    [panel setRequiredFileType:@"tgz"];
    [panel setAllowsOtherFileTypes:FALSE];
    [panel setDirectory:NSHomeDirectory()];
    [panel setCanCreateDirectories:FALSE];
    [panel setCanSelectHiddenExtension:TRUE];

	[panel setBecomesKeyOnlyIfNeeded:TRUE];
	[[NSApplication sharedApplication] activateIgnoringOtherApps:YES];

    if ([panel runModal] == NSFileHandlingPanelOKButton)
    {
        //NSLog(@"Ok: %@", [panel filename]);
		
		NSFileManager *fm = [NSFileManager defaultManager];
		NSString *dataDir = [workingDirectory stringByAppendingPathComponent:subDir];
		BOOL isDir = FALSE;
		if ([fm fileExistsAtPath:dataDir isDirectory:&isDir])
		{
			if (isDir)
			{
				NSLog(@"OK, will remove data directory");
				moveFileToUserTrash(dataDir);
			}
		}

        Archiver *archiver = [[[Archiver alloc] initWithWorkingDirectory:workingDirectory] autorelease];
        [archiver extract:[panel filename]];

        int res = NSRunAlertPanel(
            NSLocalizedString(@"ImportSucceeded", @"Import succeeded"),
            NSLocalizedString(@"ImportQueryRestart",
                              @"Successfully imported your Wiki pages from the file %@.\n\n"
                              @"Should the Wiki engine to be restarted to reflect your changes?"),
            NSLocalizedString(@"Yes", @"Yes"),
            NSLocalizedString(@"No", @"No"), nil, [panel filename]);    

        if (res == YES)
        {
            NSLog(@"Restarting wiki engine upon user request");
            [wiki restart];
        }
    }
    else
    {
        NSLog(@"Cancel import");
    }
}

- (IBAction)about:(id)sender
{
    //NSLog(@"about");
    [NSApp activateIgnoringOtherApps:YES];
    [NSApp orderFrontStandardAboutPanel:self];
}

// if the sender is nil, we're have been invoked automatically.
// thus don't annoy the user with boring alert panels that he/she/it is running
// already the newest version.
- (IBAction)checkForUpdates:(id)sender
{
    //NSLog(@"checkForUpdates");
    NSString *currVersionNumber = [[[NSBundle mainBundle]
        infoDictionary] objectForKey:@"CFBundleVersion"];
    NSDictionary *productVersionDict = [NSDictionary dictionaryWithContentsOfURL:
        [NSURL URLWithString:MOINX_VERSION_CHECK_URI]];

    if (productVersionDict == nil)
    {
        NSLog(@"Can't load version info dict via URI: %@", MOINX_VERSION_CHECK_URI);
        return;
    }

    NSString *latestVersionNumber =
        [productVersionDict valueForKey:MOINX_VERSION_CHECK_KEY];
    NSString *latestVersionDownloadURI =
        [productVersionDict valueForKey:MOINX_VERSION_DOWNLOAD_URI_KEY];

    if (latestVersionNumber == nil)
    {
        NSLog(@"*CRITICAL* Can't determine latest version number via key: %@",
              MOINX_VERSION_CHECK_KEY);
        return;
    }

    if (latestVersionDownloadURI == nil)
    {
        NSLog(@"*CRITICAL* Can't determine latest version download URI via key: %@",
              MOINX_VERSION_DOWNLOAD_URI_KEY);
        return;
    }

    if ([latestVersionNumber isEqualTo: currVersionNumber])
    {
        NSLog(@"MoinX is up to date");
        if (sender != nil)
        {
			[[NSApplication sharedApplication] activateIgnoringOtherApps:YES];

            NSRunAlertPanel(
                NSLocalizedString(@"NewVersion", @"New version"),
                NSLocalizedString(@"NewestVersionNotify",
                                  @"Your Software is up to date."
                                  @"You have the most recent version of MoinX."),
                NSLocalizedString(@"OK", @"OK"), nil, nil);
        }
    }
    else
    {
        NSLog(@"MoinX has been updated to %@", latestVersionNumber);
        NSString *msg = [NSString stringWithFormat:
            NSLocalizedString(@"NewerVersionDownloadQuery",
                              @"A new version of MoinX is available: %@.\n"
                              @"Would you like to download the new veresion?"),
            latestVersionNumber];

		[[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
        int button = NSRunAlertPanel(
            NSLocalizedString(@"NewVersion", @"New version"),
            msg,
            NSLocalizedString(@"Yes", @"Yes"),
            NSLocalizedString(@"No", @"No"), nil);

        if (button == NSOKButton)
        {
            [[NSWorkspace sharedWorkspace] openURL:[NSURL
                URLWithString:latestVersionDownloadURI]];
        }
    }
}

- (IBAction)quit:(id)sender
{
    //NSLog(@"quit");
    [NSApp terminate:self];
}

@end
