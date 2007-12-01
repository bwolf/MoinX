#-*- coding: utf-8 -*-
"""
		@copyright: 2000-2004 by Juergen Hermann <jh@web.de>
		@license: GNU GPL, see COPYING for details.

		@copyright: 2005-2006 Marcus Geiger
		$Id: wikiconfig.py 19 2005-02-20 20:55:03Z bwolf $
"""

from MoinMoin.multiconfig import DefaultConfig
import os

CFG_USTR=0
CFG_INT=1
CFG_FLOAT=2
CFG_LIST=3

def moinx_get(name, type=CFG_USTR):
	"""Author: Marcus Geiger"""
	k = 'MOINX_' + name.upper()
	if not k in os.environ.keys():
		raise StandardError, ('Missing property: %s' % k)
	v = os.environ[k]
	if type == CFG_USTR:
		return unicode(v, 'utf-8')
	elif type == CFG_INT:
		return int(v)
	elif type == CFG_FLOAT:
		return float(v)
	elif type == CFG_LIST:
		if v is None or len(v) < 1:
			return []
		u = unicode(v, 'utf-8')
		xs = u.split(',')
		if xs is None or len(xs) < 1:
			raise StandardError, ('Propety %s: not a proper list: %s' % (k, xs))
		return map(lambda x: u'%s' % x, xs)
	else:
		raise StandardError, ('Unsupported conversion requested: %s' % type)

def moinx_none_if_empty(x):
	"""Author: Marcus Geiger"""
	if x is None or len(x) < 1:
		return None
	return x

if bool(moinx_get('debug_properties', CFG_INT)):
	"""Author: Marcus Geiger"""
	global moinx_get
	sav = moinx_get
	def wrapper(name, conversion=CFG_USTR): # must be same protot. than moinx_get
		r = sav(name, conversion)
		print u'moinx_get(%s) -> [%s] %s' % (name, type(r), r)
		return r
	moinx_get = wrapper

class Config(DefaultConfig):
	"""Author: Marcus Geiger"""
	# Fixed options for twisted -----------------------------------------

	data_dir = './data/'
	data_underlay_dir = './underlay/'
	url_prefix = '/wiki'

	# Options -----------------------------------------------------------
	acl_rights_default = moinx_get('acl_rights_default')
	acl_rights_before = moinx_get('acl_rights_before')
	acl_rights_after = moinx_get('acl_rights_after')
	actions_excluded = moinx_get('actions_excluded', CFG_LIST)
	bang_meta = moinx_get('bang_meta', CFG_INT)
	changed_time_fmt = moinx_get('changed_time_fmt')
	cookie_lifetime = moinx_get('cookie_lifetime', CFG_INT)
	date_fmt = moinx_get('date_fmt')
	datetime_fmt = moinx_get('datetime_fmt')
	wiki = moinx_get('wiki')
	editor_default = moinx_get('editor_default')
	editor_ui = moinx_get('editor_ui')
	editor_force = moinx_get('editor_force', CFG_INT)
	edit_locking = moinx_get('edit_locking')
	edit_rows = moinx_get('edit_rows', CFG_INT)
	hosts_deny = moinx_get('hosts_deny', CFG_LIST)
	html_head = moinx_get('html_head')
	html_head_posts = moinx_get('html_head_posts')
	html_head_index = moinx_get('html_head_index')
	html_head_normal = moinx_get('html_head_normal')
	html_head_queries = moinx_get('html_head_queries')
	html_pagetitle = moinx_none_if_empty(moinx_get('html_pagetitle'))
	interwikiname = moinx_none_if_empty(moinx_get('interwikiname'))
	interwiki_preferred = moinx_get('interwiki_preferred', CFG_LIST)
	language_default = moinx_get('language_default')
	language_ignore_browser = moinx_get('language_ignore_browser', CFG_INT)
	logo_string = moinx_none_if_empty(moinx_get('logo_string'))
	mail_from = moinx_none_if_empty(moinx_get('mail_from'))
	mail_smarthost = moinx_none_if_empty(moinx_get('mail_smarthost'))
	mail_login = moinx_none_if_empty(moinx_get('mail_login'))
	mail_sendmail = moinx_none_if_empty(moinx_get('mail_sendmail'))
	navi_bar = moinx_get('navi_bar', CFG_LIST)
	nonexist_qm = moinx_get('nonexist_qm', CFG_INT)
	page_category_regex = moinx_get('page_category_regex')
	page_credits = moinx_get('page_credits', CFG_LIST)
	page_dict_regex = moinx_get('page_dict_regex')
	page_footer1 = moinx_get('page_footer1')
	page_footer2 = moinx_get('page_footer2')
	page_front_page = moinx_get('page_front_page')
	# page_group_regex = moinx_get('page_group_regex')							# a problem?
	page_header1 = moinx_get('page_header1')
	page_header2 = moinx_get('page_header2')
	page_license_enabled = moinx_get('page_license_enabled', CFG_INT)
	page_license_page = moinx_get('page_license_page')
	page_local_spelling_words = moinx_get('page_local_spelling_words')
	page_template_regex = moinx_get('page_template_regex')
	show_hosts = moinx_get('show_hosts', CFG_INT)
	# show_interwiki = moinx_get('show_interwiki')								# a problem?
	show_login = moinx_get('show_login')
	show_names = moinx_get('show_names', CFG_INT)
	show_section_numbers = moinx_get('show_section_numbers', CFG_INT)
	show_timings = moinx_get('show_timings', CFG_INT)
	show_version = moinx_get('show_version', CFG_INT)
	sitename = moinx_get('sitename')
	stylesheets = moinx_get('stylesheets', CFG_LIST)
	superuser = moinx_get('superuser', CFG_LIST)
	theme_default = moinx_get('theme_default')
	theme_force = moinx_get('theme_force', CFG_INT)
	trail_size = moinx_get('trail_size', CFG_INT)
	tz_offset = moinx_get('tz_offset', CFG_FLOAT)
	user_autocreate = moinx_get('user_autocreate', CFG_INT)
	user_email_unique = moinx_get('user_email_unique', CFG_INT)
	ua_spiders = moinx_get('ua_spiders')
	unzip_attachments_count = moinx_get('unzip_attachments_count', CFG_INT)
	unzip_attachments_space = moinx_get('unzip_attachments_space', CFG_INT)
	unzip_single_file_size = moinx_get('unzip_single_file_size', CFG_INT)
