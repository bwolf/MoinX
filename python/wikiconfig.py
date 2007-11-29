#-*- coding: utf-8 -*-
"""
        @copyright: 2000-2004 by Juergen Hermann <jh@web.de>
        @license: GNU GPL, see COPYING for details.

        @copyright: 2005 Marcus Geiger
        $Id: wikiconfig.py 19 2005-02-20 20:55:03Z bwolf $
"""

from MoinMoin.multiconfig import DefaultConfig
import os

def moinx_get(name):
        """Author: Marcus Geiger"""
        o = os.environ['MOINX_' + name.upper()]
        if o is None:
                raise StandardError, ('Missing property: %s' % name)
        return unicode(o, 'utf-8')

def moinx_get_int(name):
        """Author: Marcus Geiger"""
        o = os.environ['MOINX_' + name.upper()]
        if o is None:
                raise StandardError, ('Missing property: %s' % name)
        return int(o)

def moinx_get_array(name):
        """Author: Marcus Geiger"""
        o = os.environ['MOINX_' + name.upper()]
        if o is None:
                raise StandardError, ('Missing property: %s' % name)
        o = unicode(o, 'utf-8')
        v = o.split(',')
        if v is None or len(v) < 1:
                raise StandardError, 'Property %s is not a list: %s' % (name, o)
        uv = []
        for x in v:
                uv.append(u'%s' % x)
        return uv

class Config(DefaultConfig):
        """Author: Marcus Geiger"""
        # Fixed options as of twisted ---------------------------------------

        data_dir = './data/'
        data_underlay_dir = './underlay/'
        url_prefix = '/wiki'

        # Site options ------------------------------------------------------

        # Next must be unicode
        sitename = moinx_get('sitename')
        logo_string = sitename
        interwikiname = moinx_get('interwikiname')

        # Content options ---------------------------------------------------
        show_section_numbers = moinx_get_int('show_section_numbers')
        show_hosts = moinx_get_int('show_hosts')
        # Charts size, require gdchart (Set to None to disable).
        chart_options = {'width': 600, 'height': 300}
        backtick_meta = moinx_get_int('backtick_meta')
        bang_meta = moinx_get_int('bang_meta')
        allow_extended_names = moinx_get_int('allow_extended_names')
        allow_subpages = moinx_get_int('allow_subpages')
        allow_numeric_entities = moinx_get_int('allow_numeric_entities')

        # User interface ----------------------------------------------------

        # Next must be unicode
        navi_bar = moinx_get_array('navi_bar')
        allowed_actions = moinx_get_array('allowed_actions')
        edit_rows = moinx_get_int('edit_rows')
        theme_default = moinx_get('theme_default')

        # Security options ---------------------------------------------------

        acl_enabled = moinx_get_int('acl_enabled')
        acl_rights_default = moinx_get('acl_rights_default')
        acl_rights_before = moinx_get('acl_rights_before')
        acl_rights_after = moinx_get('acl_rights_after')

        # Esoteric options ---------------------------------------------------

        default_lang = moinx_get('default_lang')
        show_version = moinx_get_int('show_version')
 
        # Mail --------------------------------------------------------------
 
        mail_smarthost = moinx_get('mail_smarthost')
        mail_from = moinx_get('mail_from')
        mail_login = moinx_get('mail_login')
