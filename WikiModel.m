/* $Id: WikiModel.m 7 2005-02-05 18:45:05Z bwolf $
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
#import "WikiModel.h"

// Preference keys
static NSString *PREF_KEY_LISTEN_TYPE = @"listenType";
static NSString *PREF_KEY_LISTEN_IP = @"listenIP";
static NSString *PREF_KEY_LISTEN_PORT = @"listenPort";
static NSString *PREF_KEY_RENDEZVOUS = @"rendezvous";
static NSString *PREF_KEY_DISPLAY = @"display";
static NSString *PREF_KEY_CHECK_FOR_UPDATES = @"checkForUpdates";
static NSString *PREF_KEY_FEATURES = @"features";

// Preference default values
static const int PREF_DEF_LISTEN_TYPE = LISTEN_TYPE_LOCAL;
static NSString *PREF_DEF_LISTEN_IP = @"127.0.0.1";
static const int PREF_DEF_LISTEN_PORT = 8080;
static const BOOL PREF_DEF_RENDEZVOUS = FALSE;
static const BOOL PREF_DEF_CHECK_FOR_UPDATES = TRUE;
static const int PREF_DEF_DISPLAY = DISPLAY_MENUBAR;

// Environment keys
static NSString *MOINX_LISTEN_IP = @"MOINX_LISTEN_IP";
static NSString *MOINX_LISTEN_PORT = @"MOINX_LISTEN_PORT";

// Constants
static NSString *MOINX_SITENAME_FMT = @"%@'s MoinX Desktop Wiki";
static NSString *MOINX_ENVIRONMENT_PREFIX = @"MOINX_";

@implementation WikiModel

+ (NSDictionary *)defaultFeatureSpec
{
    static NSDictionary *spec = nil;
    if (spec != nil)
        return spec;

    NSString *siteNameDefault =
        [NSString stringWithFormat:MOINX_SITENAME_FMT, NSFullUserName()];

    // MoinMoin default configuration settings. These are not the same that
    // ship with MoinMoin in the default install as of MoinMoin 1.3.
    spec = [[NSDictionary dictionaryWithObjectsAndKeys:
        siteNameDefault,        @"sitename",
        @"",                    @"interwikiname",
        @"1",                   @"show_section_numbers",
        @"0",                   @"show_hosts",
        // --------------------------------------------------------------------
        @"1",                   @"backtick_meta",
        @"1",                   @"bang_meta",
        @"1",                   @"allow_extended_names",
        @"1",                   @"allow_subpages",
        @"1",                   @"allow_numeric_entities",
        // --------------------------------------------------------------------
        @"%(page_front_page)s,RecentChanges,FindPage,HelpContents", @"navi_bar",
        // the next is a list (separated by commas)
        @"AttachFile,DeletePage,LikePages,LocalSiteMap,RenamePage,SpellCheck", @"allowed_actions",
        @"25",                  @"edit_rows",
        @"modern",              @"theme_default",
        // --------------------------------------------------------------------
        @"0",                   @"acl_enabled",
        @"All:read",            @"acl_rights_default",
        @"YourLoginameHere:read,write,admin,delete,revert", @"acl_rights_before",
        @"",                    @"acl_rights_after",
        // --------------------------------------------------------------------
        @"en",                  @"default_lang",
        @"0",                   @"show_version",
        // --------------------------------------------------------------------
        @"",                    @"mail_smarthost",
        @"",                    @"mail_from",
        @"",                    @"mail_login",
        nil] retain];

    return spec;
}

+ (void)initialize
{
    //NSLog(@"initialize");
    NSDictionary *defaultPrefs = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithInt: PREF_DEF_LISTEN_TYPE], PREF_KEY_LISTEN_TYPE,
        PREF_DEF_LISTEN_IP, PREF_KEY_LISTEN_IP,
        [NSNumber numberWithInt:PREF_DEF_LISTEN_PORT], PREF_KEY_LISTEN_PORT,
        [NSNumber numberWithBool:PREF_DEF_RENDEZVOUS], PREF_KEY_RENDEZVOUS,
        [NSNumber numberWithInt:PREF_DEF_DISPLAY], PREF_KEY_DISPLAY,
        [NSNumber numberWithBool:PREF_DEF_CHECK_FOR_UPDATES], PREF_KEY_CHECK_FOR_UPDATES,
        [WikiModel defaultFeatureSpec], PREF_KEY_FEATURES,
        nil];

    [[NSUserDefaults standardUserDefaults] registerDefaults: defaultPrefs]; 
    //NSLog(@"registered default perferences: %@", defaultPrefs);
}

- (id)init
{
    //NSLog(@"init");
    [super init];

    // Load model from preferences
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    listenType = [prefs integerForKey:PREF_KEY_LISTEN_TYPE];
    listenIP = [[prefs stringForKey:PREF_KEY_LISTEN_IP] retain];
    listenPort = [prefs integerForKey:PREF_KEY_LISTEN_PORT];
    rendezvous = [prefs boolForKey:PREF_KEY_RENDEZVOUS];
    display = [prefs integerForKey:PREF_KEY_DISPLAY];
    checkForUpdates = [prefs boolForKey:PREF_KEY_CHECK_FOR_UPDATES];
    features = [[NSMutableDictionary dictionaryWithDictionary:
        [prefs objectForKey:PREF_KEY_FEATURES]] retain];
    // Create sorted featureKeys array
    featureKeys = [[NSMutableArray arrayWithArray:[features allKeys]] retain];
    [featureKeys sortUsingSelector:@selector(caseInsensitiveCompare:)];

    return self;
}

- (void)dealloc
{
    //NSLog(@"dealloc");

    [listenIP release];
    [features release];
    [featureKeys release];

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

- (BOOL)isModeModifiedThatRequiresWikiRestart
{
    //NSLog(@"isModeModifiedThatRequiresAWikiRestart");

    BOOL restart = FALSE;
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];

    if (listenType != [prefs integerForKey:PREF_KEY_LISTEN_TYPE])
    {
        restart = TRUE;
    }
    else if (![listenIP isEqualToString:[prefs stringForKey:PREF_KEY_LISTEN_IP]])
    {
        restart = TRUE;
    }
    else if (listenPort != [prefs integerForKey:PREF_KEY_LISTEN_PORT])
    {
        restart = TRUE;
    }
    else if (rendezvous != [prefs boolForKey:PREF_KEY_RENDEZVOUS])
    {
        restart = TRUE;
    }
    else if (![features isEqualToDictionary:[prefs objectForKey:PREF_KEY_FEATURES]])
    {
        restart = TRUE;
    }

    //NSLog(@"wiki must be restarted: %d", restart);

    return restart;
}

- (void)save
{
    //NSLog(@"save");
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];

    if (display != [prefs integerForKey:PREF_KEY_DISPLAY])
    {
        NSRunAlertPanel(@"MoinX",
            NSLocalizedString(@"DisplayPrefRequiresRestart",
            @"Changes to the display settings will be reflected when the "
            @"application is restarted."),
            NSLocalizedString(@"OK", @"OK"), nil, nil);
    }

    if (delegate != nil && [self isModeModifiedThatRequiresWikiRestart])
    {
        if ([delegate respondsToSelector:@selector(wikiNeedsToBeRestarted)])
        {
            //NSLog(@"invoking selector (wikiNeedsToBeRestarted) on delegate");
            [delegate performSelector:@selector(wikiNeedsToBeRestarted)];
        }
        else
        {
            NSLog(@"Delegate doesn't understand selector(wikiNeedsToBeRestarted)");
        }
    }

    [prefs setInteger:listenType forKey:PREF_KEY_LISTEN_TYPE];
    [prefs setObject:listenIP forKey:PREF_KEY_LISTEN_IP];
    [prefs setInteger:listenPort forKey:PREF_KEY_LISTEN_PORT];
    [prefs setBool:rendezvous forKey:PREF_KEY_RENDEZVOUS];
    [prefs setInteger:display forKey:PREF_KEY_DISPLAY];
    [prefs setBool:checkForUpdates forKey:PREF_KEY_CHECK_FOR_UPDATES];
    [prefs setObject:features forKey:PREF_KEY_FEATURES];
}

- (int)listenType
{
    return listenType;
}

- (void)setListenType:(int)lt
{
    listenType = lt;
}

- (NSString *)listenIP
{
    return listenIP;
}

- (void)setListenIP:(NSString *)ip
{
    [listenIP release];
    listenIP = [[ip copy] retain];
}

- (int)listenPort
{
    return listenPort;
}

- (void)setListenPort:(int)port
{
    listenPort = port;
}

- (BOOL)rendezvous
{
    if (listenType != LISTEN_TYPE_LOCAL)
    {
        return rendezvous;
    }
    else
    {
        return FALSE;
    }
}

- (void)setRendezvous:(BOOL)r

{
    rendezvous = r;
}

- (int)display
{
    return display;
}

- (BOOL)checkForUpdates
{
    return checkForUpdates;
}

- (void)setCheckForUpdates:(BOOL)b
{
    checkForUpdates = b;
}

- (void)setDisplay:(int)d
{
    display = d;
}

- (int)countOfFeatures
{
    return [featureKeys count];
}

- (id)featureNameForRow:(int)row
{
    NSParameterAssert(row < [featureKeys count]);
    return [featureKeys objectAtIndex:row];
}

- (id)featureValueForRow:(int)row
{
    NSParameterAssert(row < [featureKeys count]
        && [featureKeys objectAtIndex:row] != nil
        && [features objectForKey:[featureKeys objectAtIndex:row]] != nil);
    return [features objectForKey:[featureKeys objectAtIndex:row]];
}

- (void)setFeatureValueForRow:(id)value row:(int)row
{
    NSParameterAssert(row < [featureKeys count]
        && [featureKeys objectAtIndex:row] != nil
        && [features objectForKey:[featureKeys objectAtIndex:row]] != nil);
    NSString *key = [featureKeys objectAtIndex:row];
    // don't release oldValue, NSMutableDictionary does it for us
    [features setObject:[value retain] forKey:key];
}

- (id)featureForKey:(NSString *)key
{
    NSParameterAssert([features objectForKey:key] != nil);
    return [features objectForKey:key];
}

- (NSMutableDictionary *)moinxStartupEnvironment
{
    //NSLog(@"moinxStartupEnvironment");
    NSMutableDictionary *env =
        [[[NSMutableDictionary dictionaryWithCapacity:
            [featureKeys count]] retain] autorelease];

    // Add features
    NSEnumerator *objEnum = [featureKeys objectEnumerator];
    NSString *key, *envKey, *val;
    while (key = [objEnum nextObject])
    {
        envKey = [MOINX_ENVIRONMENT_PREFIX stringByAppendingString:
            [key uppercaseString]];
        val = [features objectForKey:key];
        [env setObject:val forKey:envKey];
    }

    // Add essential settings
    NSString *ip;
    if (listenType == LISTEN_TYPE_LOCAL)
    {
        ip = @"127.0.0.1";
    }
    else if (listenType == LISTEN_TYPE_ALL)
    {
        ip = @"";
    }
    else if (listenType == LISTEN_TYPE_SPECIFIC)
    {
        ip = listenIP;
    }
    else
    {
        ip = nil;
        NSAssert(FALSE, @"unknown listenType");
    }
    [env setObject:ip forKey:MOINX_LISTEN_IP];
    [env setObject:[NSNumber numberWithInt:listenPort] forKey:MOINX_LISTEN_PORT];

    return env;
}

@end
