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
#import "PreferenceController.h"
#import "Wiki.h"
#import "WikiModel.h"

@interface AppDelegate : NSObject
{
    IBOutlet NSMenu         *statusMenu;
    NSStatusItem            *statusItem;
    PreferenceController    *preferenceController;
    WikiModel               *model;
    Wiki                    *wiki;
}

// Wiki delegate methods
- (void)wikiStarted;
- (void)wikiStopped:(NSNumber *)exitStatus;

// WikiModel delegate methods
- (void)wikiNeedsToBeRestarted;

// Helper methods
- (void)setStatus:(BOOL)status;

// UI
- (IBAction)goToHomepage:(id)sender;
- (IBAction)showPreferencePanel:(id)sender;
- (IBAction)export:(id)sender;
- (IBAction)import:(id)sender;
- (IBAction)about:(id)sender;
- (IBAction)checkForUpdates:(id)sender;
- (IBAction)quit:(id)sender;

@end
