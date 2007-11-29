/* $Id: Archiver.m 8 2005-02-05 18:46:15Z bwolf $
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
#import <sys/stat.h>
#import <fcntl.h>
#import <stdio.h>
#import <archive.h>
#import <archive_entry.h>
#import "Archiver.h"

#define READ_BUFFER_SIZE 8192

@implementation Archiver

- (id)initWithWorkingDirectory:(NSString *)dir
{
    //NSLog(@"initWithWorkingDirectory: %@", dir);

    [super init];
    workingDirectory = [dir retain];

    return self;
}

- (void)dealloc
{
    //NSLog(@"dealloc");
    [workingDirectory release];
    if (errorString != nil)
        [errorString release];
    [super dealloc];
}

- (BOOL)extract:(NSString *)archive
{
    NSLog(@"changing working directory to: %@", workingDirectory);
    NSFileManager *fmgr = [NSFileManager defaultManager];
    NSString *currentDirectory = [fmgr currentDirectoryPath];

    if (![fmgr changeCurrentDirectoryPath:workingDirectory])
    {
        NSString *es = [NSString stringWithFormat:
            NSLocalizedString(@"ChangeDirFailed",
                              @"Changing directory to %@ failed.\nCan't extract"),
            workingDirectory];
        [self _setErrorString:es];
        NSLog(@"%@", es);
        return FALSE;
    }

    NSLog(@"unarchiving %@ in %@", archive, workingDirectory);
    BOOL result = [self _extract:archive];

    NSLog(@"changing back working directory to: %@", currentDirectory);
    [fmgr changeCurrentDirectoryPath:currentDirectory]; // ignore errors

    return result;
}

- (BOOL)_extract:(NSString *)archive
{
    struct archive *a;
    struct archive_entry *entry;

    a = archive_read_new();
    archive_read_support_compression_all(a);
    archive_read_support_format_all(a);

    if (archive_read_open_file(a, [archive UTF8String], READ_BUFFER_SIZE) != ARCHIVE_OK)
    {
        NSString *es = [NSString stringWithCString:archive_error_string(a)];
        archive_read_finish(a);
        [self _setErrorString:es];
        NSLog(@"%@", es);
        return FALSE;
    }

    while (archive_read_next_header(a, &entry) == ARCHIVE_OK)
    {
        // for printing only use 'archive_read_data_skip(a)' to skip the entry
        NSLog(@"%s", archive_entry_pathname(entry));
        archive_read_extract(a, entry, ARCHIVE_EXTRACT_NO_OVERWRITE);
    }

    archive_read_finish(a);
    return TRUE;
}

- (BOOL)create:(NSString *)archive fromSubDirectory:(NSString *)subDir
{
    NSFileManager *fmgr = [NSFileManager defaultManager];
    NSString *currentDirectory = [fmgr currentDirectoryPath];

    NSLog(@"changing working directory to: %@", workingDirectory);
    if (![fmgr changeCurrentDirectoryPath:workingDirectory])
    {
        NSString *es = [NSString stringWithFormat:
            NSLocalizedString(@"ChangeDirFailed",
                              @"Changing directory to %@ failed.\nCan't extract"),
            workingDirectory];
        [self _setErrorString:es];
        NSLog(@"%@", es);
        return FALSE;
    }

    // The subdirectory we try to archive is relative to the working directory
    NSArray *fileList = [fmgr subpathsAtPath:subDir];
    NSEnumerator *fileEnum = [fileList objectEnumerator];

    NSLog(@"archiving subdir %@ in %@ to %@", subDir, workingDirectory, archive);
    BOOL result = [self _create:archive fromSubDir:subDir withFileList:fileEnum];

    NSLog(@"changing back working directory to: %@", currentDirectory);
    [fmgr changeCurrentDirectoryPath:currentDirectory]; // ignore errors

    return result;
}

- (BOOL)_create:(NSString *)archive fromSubDir:(NSString *)subDir withFileList:(NSEnumerator *)fileList
{
    struct archive *a;
    int status;
    NSString *basePath;
    NSString *file;
    const char *cFile;
    NSString *pathName;
    struct stat st;
    struct archive_entry *entry;
    char buf[8192];
    ssize_t len;
    int fd;

    a = archive_write_new();
    archive_write_set_compression_gzip(a);
    archive_write_set_format_ustar(a);

    status = archive_write_open_file(a, [archive UTF8String]);
    if (status != ARCHIVE_OK && status != ARCHIVE_WARN)
    {
        NSString *es= [NSString stringWithCString:archive_error_string(a)];
        [self _setErrorString:es];
        archive_write_finish(a);
        NSLog(@"%@", es);
        return FALSE;
    }

    basePath = [workingDirectory stringByAppendingPathComponent:subDir];
    while (file = [fileList nextObject])
    {
        cFile = [[[workingDirectory stringByAppendingPathComponent:subDir]
            stringByAppendingPathComponent:file] UTF8String];
        NSAssert(cFile, @"cFile must be non NULL");

        if (stat(cFile, &st) != 0)
        {
            NSString *es = [NSString stringWithCString:strerror(errno)];
            [self _setErrorString:es];
            archive_write_finish(a);
            NSLog(@"%@", es);
            return FALSE;
        }

        entry = archive_entry_new();
        archive_entry_copy_stat(entry, &st);
        // Adding pathName to the archive controls how the file is stored into
        // the archive.
        pathName = [subDir stringByAppendingPathComponent:file];
        NSLog(@"adding file: %@", pathName);
        archive_entry_set_pathname(entry, [pathName UTF8String]);
        archive_write_header(a, entry);

        if ((fd = open(cFile, O_RDONLY)) == -1)
        {
            NSString *es = [NSString stringWithCString:strerror(errno)];
            [self _setErrorString:es];
            archive_write_finish(a);
            NSLog(@"%@", es);
            return FALSE;
        }

        // This is no error! we can't read a directory, but doing it that way
        // is quite simple.
        len = read(fd, buf, sizeof(buf));
        while (len > 0)
        {
            archive_write_data(a, buf, len);
            len = read(fd, buf, sizeof(buf));
        }

        close(fd);
        archive_entry_free(entry);
    }

    archive_write_finish(a);
    return TRUE;
}

- (void)_setErrorString:(NSString *)es;
{
    [errorString autorelease];
    errorString = [es retain];
}

- (NSString *)errorString
{
    return errorString;
}

@end

