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
#import "WikiModel.h"

// Preference keys
static NSString *PREF_KEY_LISTEN_TYPE = @"listenType";
static NSString *PREF_KEY_LISTEN_IP = @"listenIP";
static NSString *PREF_KEY_LISTEN_PORT = @"listenPort";
static NSString *PREF_KEY_BONJOUR = @"bonjour";
static NSString *PREF_KEY_DISPLAY = @"display";
static NSString *PREF_KEY_CHECK_FOR_UPDATES = @"checkForUpdates";
static NSString *PREF_KEY_FEATURES = @"features";

// Preference default values
static const int PREF_DEF_LISTEN_TYPE = LISTEN_TYPE_LOCAL;
static NSString *PREF_DEF_LISTEN_IP = @"127.0.0.1";
static const int PREF_DEF_LISTEN_PORT = 8080;
static const BOOL PREF_DEF_BONJOUR = FALSE;
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
    // ship with MoinMoin in the default install as of MoinMoin 1.5.
    spec = [[NSDictionary dictionaryWithObjectsAndKeys:
		// --------------------------------------------------------------------
		// Set the following setting to 1, to dump environment variables during
		// startup and enable debug output.
		/* I */ @"0",			@"debug_properties",
		// --------------------------------------------------------------------
		// MoinX 1.0.1 settings for ACLs:
        //@"0",                   @"acl_enabled",
        //@"All:read",            @"acl_rights_default",
        //@"YourLoginameHere:read,write,admin,delete,revert", @"acl_rights_before",
        //@"",                    @"acl_rights_after",
		// --------------------------------------------------------------------
		/* S */	@"Trusted:read,write,delete,revert " // trailing space needed
				@"Known:read,write,delete,revert All:read,write",
								@"acl_rights_default",
	    /* S */	@"", 			@"acl_rights_before",
	    /* S */	@"",			@"acl_rights_after",
		/* I */	//@"",			@"allow_xslt",
		/* L */	@"",			@"actions_excluded",
		/* D */	//@"",			@"attachments",
		/* L */	//@"",			@"auth",
		/* I */	@"1",			@"bang_meta",
		/* S */ @"%H:%M",		@"changed_time_fmt",
		/* D */ //@"",			@"chart_options",
		/* S */ //@"",			@"cookie_domain",
		/* S */ //@"",			@"cookie_path",
		/* I */ @"12",			@"cookie_lifetime",
		/* S */ @"%Y-%m-%d",	@"date_fmt",
		/* S */ @"%Y-%m-%d %H:%M:%S",
								@"datetime_fmt",
		/* S */ @"default_markup",
								@"wiki",
		/* S */ @"text",		@"editor_default",
		/* S */ @"freechoice",	@"editor_ui",
		/* B */ @"0",			@"editor_force",
		/* S */ @"warn 10",		@"edit_locking",
		/* I */ @"20",			@"edit_rows",
		/* L */ @"",			@"hosts_deny",
		/* S */ @"",			@"html_head",
		/* S */ @"<meta name='robots' content='noindex,nofollow'>",	
								@"html_head_posts",
		/* S */ @"<meta name='robots' content='index,follow'>",
								@"html_head_index",
		/* S */ @"<meta name='robots' content='index,nofollow'>",
								@"html_head_normal",
		/* S */ @"<meta name='robots' content='noindex,nofollow'>",
								@"html_head_queries",
		/* S */ @"",			@"html_pagetitle",
		/* S */ @"",			@"interwikiname",
		/* L */ @"",			@"interwiki_preferred",
		/* S */ @"en",			@"language_default",
		/* B */ @"0",			@"language_ignore_browser",
		/* S */ siteNameDefault,@"logo_string",
		/* B */ //@"0",			@"lupy_search",				// not finished now
		/* S */ @"",			@"mail_from",
		/* S */ @"",			@"mail_smarthost",
		/* S */ //@"",			@"mail_import_subpage_template",
		/* S */ //@"",			@"mail_import_wiki_address",
		/* S */ //@"",			@"mail_import_secret",
		/* S */ @"",			@"mail_login",
		/* S */ @"",			@"mail_sendmail",
		/* L */ @"%(page_front_page)s,RecentChanges,FindPage,HelpContents",
								@"navi_bar",
		/* I */ @"0",			@"nonexist_qm",
		/* S */ @"^Category[A-Z]",
								@"page_category_regex",
		/* L */ @"<a href='http://moinmoin.wikiwikiweb.de/'>MoinMoin Powered</a>,"
				@"<a href='http://www.python.org/'>Python Powered</a>",
								@"page_credits",
		/* S */ @"[a-z0-9]Dict$",
								@"page_dict_regex",
		/* S */ @"",			@"page_footer1",
		/* S */ @"",			@"page_footer2",
		/* S */ @"FrontPage",	@"page_front_page",
		/* S */ @"[a-z0-9]Group$",
								@"page_group_regex",
		/* S */ @"",			@"page_header1",
		/* S */ @"", 			@"page_header2",
		/* L */ //@'up','edit','view','diff','info','subscribe','raw','print'",
				//				@"page_iconbar"
		/* B */ @"0",			@"page_license_enabled",
		/* S */ @"WikiLicense",	@"page_license_page",
		/* S */ @"LocalSpellingWords",
								@"page_local_spelling_words",
		/* S */ @"[a-z0-9]Template$",
								@"page_template_regex",
		/* L */ //@"",			@"refresh",
		/* L */ //@"",			@"shared_intermap",
		/* I */ @"1",			@"show_hosts",
		/* I */ @"0",			@"show_interwiki",
		/* I */ @"1",			@"show_login",
		/* B */ @"1",			@"show_names",
		/* I */ @"0",			@"show_section_numbers",
		/* I */ @"0",			@"show_timings",
		/* I */ @"0",			@"show_version",
		/* S */ siteNameDefault,@"sitename",
		/* L */ @"",			@"stylesheets",
		/* L */ @"",			@"superuser",
		/* S */ @"modern",		@"theme_default",
		/* B */ @"0",			@"theme_force",
		/* I */ @"5",			@"trail_size",
		/* D */ @"0.0",			@"tz_offset",
		/* B */ @"0",			@"user_autocreate",
		/* D */ //@"",			@"user_checkbox_defaults",
		/* L */ //@"",			@"user_checkbox_disable",
		/* L */ //@"",			@"user_checkbox_fields",
		/* L */ //@"",			@"user_checkbox_remove",
		/* D */ //@"",			@"user_form_defaults",
		/* L */ //@"",			@"user_form_disable",
		/* L */ //@"",			@"user_form_fields",
		/* L */ //@"",			@"user_form_remove",
		/* S */ //@"Self",		@"user_homewiki",			// it's really a string!
		/* B */ @"1",			@"user_email_unique",
		/* S */ @"archiver|cfetch|crawler|curl|gigabot|google|holmes|htdig|httrack|"
				@"httpunit|jeeves|larbin|leech|linkbot|linkmap|linkwalk|mercator|"
				@"mirror|msnbot|nutbot|omniexplorer|puf|robot|scooter|search|"
				@"sherlock|sitecheck|spider|teleport|voyager|webreaper|wget",
								@"ua_spiders",
		/* D */ //@"", 			@"url_mappings",
		/* S */ //@"",			@"url_prefix",
		/* I */ @"51",			@"unzip_attachments_count",	// 1 zip file + 50 
															// files contained in it
		/* I */ @"200000000",	@"unzip_attachments_space",
		/* I */ @"2000000",		@"unzip_single_file_size",
		/* I */ //@"0",			@"xmlrpc_putpage_enabled",
		/* I */ //@"1",			@"xmlrpc_putpage_trusted_only",
        // --------------------------------------------------------------------
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
        [NSNumber numberWithBool:PREF_DEF_BONJOUR], PREF_KEY_BONJOUR,
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
    bonjour = [prefs boolForKey:PREF_KEY_BONJOUR];
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
    else if (bonjour != [prefs boolForKey:PREF_KEY_BONJOUR])
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
    [prefs setBool:bonjour forKey:PREF_KEY_BONJOUR];
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

- (BOOL)bonjour
{
    if (listenType != LISTEN_TYPE_LOCAL)
    {
        return bonjour;
    }
    else
    {
        return FALSE;
    }
}

- (void)setBonjour:(BOOL)r
{
    bonjour = r;
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
