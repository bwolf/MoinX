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

@interface NSObject (WikiDelegate)
- (void)wikiStarted;
- (void)wikiStopped:(NSNumber *)exitStatus;
@end

@interface Wiki : NSObject
{
@private
    NSBundle        *bundle;
    NSTask          *task;
    NSNetService    *service;
    NSTimer         *childPollTimer;
    id              delegate;
    WikiModel       *model;
}

// init
- (id)initWithBundle:(NSBundle *)aBundle model:(WikiModel *)wikiModel;

// delegate
- (id)delegate;
- (void)setDelegate:(id)aObject;

// controling the wiki
- (void)start;
- (void)stop;
- (void)restart;
- (BOOL)isRunning;

// other info
- (NSString *)instanceDirectory;

// private members
- (NSString *)_lazyCreateWikiInstance;
- (void)_timer:(NSTimer *)timer;

@end
