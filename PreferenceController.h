/* $Id$
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
#import <Cocoa/Cocoa.h>
#import "WikiModel.h"

@interface PreferenceController : NSWindowController {
    IBOutlet NSMatrix       *listenType;
    IBOutlet NSTextField    *listenIP;
    IBOutlet NSTextField    *listenPort;
    IBOutlet NSButton       *bonjour;
    IBOutlet NSPopUpButton  *display;
    IBOutlet NSButton       *checkForUpdates;
    IBOutlet NSTableView    *wikiFeaturesTableView; 
    WikiModel               *model;
}

// Init
- (id)initWithModel:(WikiModel *)wModel;

// Action methods
- (IBAction)listenTypeChanged:(id)sender;
- (IBAction)listenIPChanged:(id)sender;
- (IBAction)listenPortChanged:(id)sender;
- (IBAction)bonjourChanged:(id)sender;
- (IBAction)displayChanged:(id)sender;
- (IBAction)checkForUpdatesChanged:(id)sender;

// Table view data source methods
- (int)numberOfRowsInTableView:(NSTableView *)aTableView;
- (id)tableView:(NSTableView *)tableView
    objectValueForTableColumn:(NSTableColumn *)tableColumn
    row:(int)tableRow;
- (void)tableView:(NSTableView *)aTableView
    setObjectValue:(id)anObject
    forTableColumn:(NSTableColumn *)aTableColumn
    row:(int)rowIndex;

// Delegate methods
- (BOOL)windowShouldClose:(id)sender;
- (void)windowWillClose:(NSNotification *)aNotification;

// Helper methods
- (void)processListenTypeChanged;
- (BOOL)addressValid;
- (BOOL)portValid;

@end
