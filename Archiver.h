/* $Id: Archiver.h 7 2005-02-05 18:45:05Z bwolf $
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

@interface Archiver : NSObject
{
    NSString *workingDirectory;
    NSString *errorString;
};

// Initialisation
- (id)initWithWorkingDirectory:(NSString *)dir;

// Operations
- (BOOL)extract:(NSString *)archive;
- (BOOL)create:(NSString *)archive
    fromSubDirectory:(NSString *)subDir;

// Querying errors
- (NSString *)errorString;

// Private methods
- (void)_setErrorString:(NSString *)es;
- (BOOL)_extract:(NSString *)archive;
- (BOOL)_create:(NSString *)archive
    fromSubDir:(NSString *)subDir
    withFileList:(NSEnumerator *)fileList;

@end
