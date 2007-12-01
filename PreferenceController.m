/* $Id: PreferenceController.m 7 2005-02-05 18:45:05Z bwolf $
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
#import "PreferenceController.h"

@implementation PreferenceController

- (id)initWithModel:(WikiModel *)wModel
{
    //NSLog(@"initWithModel");
    self = [super initWithWindowNibName:@"Preferences"];
    model = [wModel retain];
    return self;
}

- (void)dealloc
{
    //NSLog(@"dealloc");
    [model release];
    [super dealloc];
}

- (void)awakeFromNib
{
    //NSLog(@"awakeFromNib");
    [wikiFeaturesTableView setDataSource:self];
    [wikiFeaturesTableView setDelegate:self];
}

- (void)windowDidLoad
{
    //NSLog(@"windowDidLoad");
    [listenType selectCellAtRow:[model listenType] column:0];
    [listenIP setStringValue:[model listenIP]];
    [listenPort setIntValue:[model listenPort]];
    [bonjour setIntValue:[model bonjour]];
    [display selectItemAtIndex:[model display]];
    [checkForUpdates setIntValue:[model checkForUpdates]];

    [self processListenTypeChanged];
}

- (IBAction)listenTypeChanged:(id)sender
{
    //NSLog(@"listenTypeChanged: %D", [listenType selectedRow]);
    [self processListenTypeChanged];

    if ([model listenType] != [listenType selectedRow])
    {
        [model setListenType:[listenType selectedRow]];
    }
}

- (IBAction)listenIPChanged:(id)sender
{
    //NSLog(@"listenIPChanged");
    if ([self addressValid]
        && ![[model listenIP] isEqualToString:[listenIP stringValue]])
    {
        [model setListenIP:[listenIP stringValue]];
    }
}

- (IBAction)listenPortChanged:(id)sender
{
    //NSLog(@"listenPortChanged");  
    if ([self portValid]
        && [model listenPort] != [listenPort intValue])
    {
        [model setListenPort:[listenPort intValue]];
    }
}

- (IBAction)bonjourChanged:(id)sender
{
    //NSLog(@"bonjourChanged");  
    if ([model bonjour] != [bonjour intValue])
    {
        [model setBonjour:[bonjour intValue]];
    }
}

- (IBAction)displayChanged:(id)sender
{
    //NSLog(@"displayChanged"); 
    if ([model display] != [display indexOfSelectedItem])
    {
        [model setDisplay:[display indexOfSelectedItem]];
    }
}

- (IBAction)checkForUpdatesChanged:(id)sender
{
    //NSLog(@"checkForUpdatesChanged");
    if ([model checkForUpdates] != [checkForUpdates intValue])
    {
        [model setCheckForUpdates:[checkForUpdates intValue]];
    }
}

// NSPanel delegate method
- (BOOL)windowShouldClose:(id)sender
{
    //NSLog(@"windowShouldClose");
    if ([listenType selectedRow] == LISTEN_TYPE_SPECIFIC && !([self addressValid]))
    {
        NSLog(@"IP address is invalid: %@", [listenIP stringValue]);
        NSRunAlertPanel(nil,
            NSLocalizedString(@"InvalidIPEntered",
                @"The IP address you entered is invalid. Please enter a valid "
                @"IP address like 123.12.0.1."),
            NSLocalizedString(@"OK", @"OK"), nil, nil);

        return NO;
    }

    if (![self portValid])
    {
        NSLog(@"Port is invalid: %@", [listenPort stringValue]);
        NSRunAlertPanel(nil,
            NSLocalizedString(@"InvalidPortEntered",
                @"The port you entered is invalid. Please enter a valid port "
                @"like 8080 (must be greater 1024 and less than 65535)."),
            NSLocalizedString(@"OK", @"OK"), nil, nil);

        return NO;
    }

    return YES;
}

// NSWindow delegate method
- (void)windowWillClose:(NSNotification *)aNotification
{
    //NSLog(@"windowWillClose");
    [model save];
}

// NSTableView delegate method
- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
    //NSLog(@"numberOfRowsInTableView");
    return [model countOfFeatures];
}

// NSTableView delegate method
- (id)tableView:(NSTableView *)tableView
    objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)tableRow
{
    //NSLog(@"tableView:objectValueForTableColumn%@:row", [tableColumn identifier]);
    NSParameterAssert(([[tableColumn identifier] isEqualToString:@"feature"]
                       || [[tableColumn identifier] isEqualToString:@"value"])
                      && tableRow < [model countOfFeatures]);

    if ([[tableColumn identifier] isEqualToString:@"feature"])
    {
        return [model featureNameForRow:tableRow];
    }
    else if ([[tableColumn identifier] isEqualToString:@"value"])
    {
        return [model featureValueForRow:tableRow];
    }
    else
    {       
        NSAssert(FALSE, @"should never happen");
        return nil;
    }
}

// NSTableView delegate method
- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject
    forTableColumn:(NSTableColumn *)tableColumn row:(int)tableRow
{
    //NSLog(@"tableView:setObjectValue:forTableColumn:row");
    NSParameterAssert([[tableColumn identifier] isEqualToString:@"value"]
                      && tableRow < [model countOfFeatures]
                      && anObject != nil);  

    if ([[tableColumn identifier] isEqualToString:@"value"])
    {
        [model setFeatureValueForRow:anObject row:tableRow];
    }
}

- (void)processListenTypeChanged
{
    //NSLog(@"self listenType is: %D", lt);
    int lt = [listenType selectedRow];

    if (lt == LISTEN_TYPE_LOCAL)
    {
        [listenIP setEnabled:FALSE];
        [bonjour setEnabled:FALSE];
    }
    else if (lt == LISTEN_TYPE_ALL)
    {
        [listenIP setEnabled:FALSE];
        [bonjour setEnabled:TRUE];
    }
    else if (lt == LISTEN_TYPE_SPECIFIC)
    {
        [listenIP setEnabled:TRUE];
        [bonjour setEnabled:TRUE];
    }
    else
    {
        NSAssert(FALSE, @"unknown listen type");
    }
}

- (BOOL)addressValid
{
    NSArray *ipItems = [[listenIP stringValue] componentsSeparatedByString:@"."];
    int n, value;
    NSString *tmp;
    size_t len;
    size_t u;
    const char *rawT;

    if ([ipItems count] != 4)
        return FALSE;

    for (n = 0; n < 4; n++)
    {
        value = -1;
        value = [[ipItems objectAtIndex:n] intValue];

        if (n == 0 || n == 3)
        {
            if (value < 1 || value > 254)
            {
                //NSLog(@"IP address tuple invalid: %@", [ipItems objectAtIndex:n]);
                return FALSE;
            }
        }
        else
        {
            tmp = [ipItems objectAtIndex:n];
            rawT = [tmp UTF8String];
            len = strlen(rawT);

            for (u = 0; u < len; u++)
            {
                if (!isdigit(rawT[u]))
                {
                    //NSLog(@"Scanned invalid tupple %d atChar %u: %c", n, u, rawT[u]);
                    return FALSE;
                }
            }

            if (value < 0 || value > 255)
            {
                //NSLog(@"IP address tuple invalid: %@", tmp);
                return FALSE;
            }
        }
    }

    return TRUE;
}

- (BOOL)portValid
{
    NSString *p = [listenPort stringValue];
    const char *raw = [p UTF8String];
    size_t n, value;
    size_t len = strlen(raw);

    for (n = 0; n < len; n++)
    {
        if (!isdigit(raw[n]))
            return FALSE;
    }

    value = [listenPort intValue];
    if (value <= 1024 || value >= 65535)
        return FALSE;

    return TRUE;
}

@end
