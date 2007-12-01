/* $Id: WikiModel.h 7 2005-02-05 18:45:05Z bwolf $
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

enum { LISTEN_TYPE_LOCAL=0, LISTEN_TYPE_ALL=1, LISTEN_TYPE_SPECIFIC=2 };
enum { DISPLAY_MENUBAR=0, DISPLAY_DOCK=1, DISPLAY_MENUBAR_AND_DOCK=2 };

@interface NSObject (WikiModelDelegate)
- (void)wikiNeedsToBeRestarted;
@end

@interface WikiModel : NSObject {
    int                 listenType;
    NSString            *listenIP;
    int                 listenPort;
    BOOL                bonjour;
    int                 display;
    BOOL                checkForUpdates;
    NSMutableDictionary *features;
    NSMutableArray      *featureKeys;
    id                  delegate;
}

// Delegate methods
- (id)delegate;
- (void)setDelegate:(id)aObject;

// Saving the model to preferences
- (void)save;
- (BOOL)isModeModifiedThatRequiresWikiRestart;

// Getter/setters
- (int)listenType;
- (void)setListenType:(int)lt;
- (NSString *)listenIP;
- (void)setListenIP:(NSString *)ip;
- (int)listenPort;
- (void)setListenPort:(int)port;
- (BOOL)bonjour;
- (void)setBonjour:(BOOL)r;
- (int)display;
- (void)setDisplay:(int)d;
- (BOOL)checkForUpdates;
- (void)setCheckForUpdates:(BOOL)b;

// Accessors for wikiFeatures
- (int)countOfFeatures;
- (id)featureNameForRow:(int)row;
- (id)featureValueForRow:(int)row;
- (void)setFeatureValueForRow:(id)value row:(int)row;
- (id)featureForKey:(NSString *)key;

// Get MoinX environment dictionary
- (NSMutableDictionary *)moinxStartupEnvironment;

@end
