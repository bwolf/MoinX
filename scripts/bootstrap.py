#! /usr/bin/env python

# Copyright: 2007 Marcus Geiger <moinx@antbear.org> for bootstrapping MoinX.
# 
# Originally created on Wed Jun 21 17:52:25 CEST 2006 with PLT scheme.
# 
# NOTES:
#  0) create a common directory for the required 3rd party packages
#  1) download MoinMoin and place it into the common dir
#  2) download Twisted and place it into the common dir
#  3) download libarchive and place it into the common dir
#  4) ensure that you use only tested releases 3rd party packages
#  5) edit the user configuration section (see below)
#  6) run this script from the project base directory
#  7) keep in mind, that this script is modified according to the
#     3rd party package version. Thus it may not work with older
#     or newer releases of them
# 
# DOWNLOAD URLS
#  a) MoinMoin:   http://moinmo.in/
#  b) Twisted:    http://twistedmatrix.com/
#  c) libarchive: http://people.freebsd.org/~kientzle/libarchive/
# 
# TESTED PRODUCT VERSIONs
#   I) MoinMoin:   1.3.1, 1.3.3, 1.3.5, 1.5.3, 1.5.8
#  II) Twisted:    1.3.0, 2.4.0, 2.5.0
# III) libarchive: 1.01.022, 1.02.002, 1.02.030, 1.2.53, 2.4.0 

from __future__ import with_statement
from subprocess import Popen, PIPE

import os, os.path, sys, shutil, glob, re

# -------------------------------------------------------------------
# BEGIN USER CONFIGURATION SECTION
# Base directory for distribution files.
user_config_dist_base = '/tmp/moinx-distfiles/'
user_config_moin_basename = 'moin-1.5.8.tar.gz'
user_config_moin_version = 'moin-1.5.8'
user_config_twisted_basename = 'Twisted-2.5.0.tar.bz2'
user_config_twisted_version = 'Twisted-2.5.0'
user_config_twisted_zope_interface_version = 'zope.interface-3.3.0'
user_config_twisted_core_version = 'TwistedCore-2.5.0'
user_config_twisted_web_version = 'TwistedWeb-0.7.0'
user_config_libarchive_basename = 'libarchive-2.4.0.tar.gz'
user_config_libarchive_version = 'libarchive-2.4.0'
# END USER CONFIGURATION SECTION
#  ------------------------------------------------------------------

# -------------------------------------------------------------------
# BEGIN NOT SO OFTEN CHANGED CONFIGURATION
verbose_enabled = False
universal_binary_cflags = '-isysroot /Developer/SDKs/MacOSX10.4u.sdk -arch ppc -arch i386 ' \
	+ '-mmacosx-version-min=10.4'
universal_binary_configure_args = '--disable-dependency-tracking'
# END NOT SO OFTEN CHANGED CONFIGURATION
# -------------------------------------------------------------------

# Build pathes out of the user supplied configuration (see above).
# Note: the variables `user-config/*' are not used directly.
dist_base = user_config_dist_base
dist_moin = os.path.join(dist_base, user_config_moin_basename)
moin_release = user_config_moin_version
dist_twisted = os.path.join(dist_base, user_config_twisted_basename)
twisted_release = user_config_twisted_version
twisted_zope_interface_release = user_config_twisted_zope_interface_version
twisted_core_release = user_config_twisted_core_version
twisted_web_release = user_config_twisted_web_version
dist_libarchive = os.path.join(dist_base, user_config_libarchive_basename)
libarchive_release = user_config_libarchive_version

# -------------------------------------------------------------------
# Utilities
# -------------------------------------------------------------------

def log(fmt, *rest):
	if verbose_enabled:
		print(fmt % rest)

def echo(fmt, *rest):
	print fmt % rest

def fail(fmt, *rest):
	print >>sys.stderr, fmt % rest
	sys.exit(1) 

def remove_directories(dir_list):
	for dir in dir_list:
		echo('cleaning up %s', dir)	
		if os.path.isfile(dir) or os.path.isdir(dir):
			log('really deleting %s', dir)
			shutil.rmtree(dir) # raises on failure
			
def make_directories(dir_list):
	for dir in dir_list:
		log('mkdir %s', dir)
		if not os.path.isdir(dir):
			os.mkdir(dir)

# Synchronously run the given command through the shell and
# capture standard output.
#
# Returns the standard output or False if the command failed
def system_output(cmd):
	p = None
	try:
		p = Popen(cmd, stdout=PIPE, close_fds=True, shell=True)
		if p.wait() < 0:
			raise 'Child (%s) kill by signal %d' % (cmd, p.returncode)
		elif p.returncode != 0:
			return False
		else:
			lines = p.stdout.readlines()
			return lines
	finally:
		if p is not None and p.stdout is not None:
			p.stdout.close()
			p = None

def shell_command(cmd):
	rc = os.system(cmd)
	code = (rc >> 8) & 0x00FF
	sign = rc & 0x00FF
	if sign != 0: # dies by signal
		raise('Process died by signal %d' % sign)
	return code == 0

def extract_archive(fpath):
	args = None
	if fpath.endswith('.tar.bz2'):
		args = 'xfj'
	elif fpath.endswith('.tar.gz') or fpath.endswith('.tgz'):
		args = 'xfz'
	elif fpath.endswith('.tar'):
		args = 'xf'
	else:
		fail('Given archive file has unknown suffix: %s', fpath)
	echo('Extracting (%s) %s', args, fpath)
	if not shell_command('tar %s "%s"' % (args, fpath)):
		fail('Failed to extract archive file %s', fpath)

class DirectorySentinel:
	def __init__(self, newdir):
		self._directory = os.getcwd()
		os.chdir(newdir)

	def restore(self):
		os.chdir(self._directory)

def run_python_install(name, build_dir, source_dir, install_log, 
					   quiet=True, silent_stdout=True):
	echo('*** building %s in %s', name, source_dir)	
	echo('... installation logfile in %s', install_log)
	echo('... install dir is %s', build_dir)
	cwd = DirectorySentinel(source_dir)
	try:
		cmd = 'python setup.py %sinstall --prefix=%s --record=%s' % \
			(('--quiet ' if quiet else ''), build_dir, install_log)
		if silent_stdout:
			cmd = cmd + '>/dev/null'
		if not shell_command(cmd):
			fail('Failed to build %s', name)		
	finally:
		cwd.restore()
	print

class EnvironmentSentinel:
	def __init__(self, envdict):
		self._oldenv = os.environ.copy()
		for k, v in envdict.items():
			os.environ[k] = v

	def restore(self):
		os.environ = self._oldenv

def run_make_c_package(name, action_name, build_dir, source_dir, log_file, fmt,
					   args=[], envd={}):
	echo('*** %s %s in %s', action_name, name, source_dir)
	echo('... %s logfile in %s', action_name, log_file)
	echo('... installation dir is %s', build_dir)
	echo('... -> running %s', action_name)
	cwd = DirectorySentinel(source_dir)
	try:
		env = EnvironmentSentinel(envd)
		try:
			if not shell_command(fmt % args):
				fail('Failed to run %s' % action_name)
		finally:
			env.restore()
	finally:
		cwd.restore()
	print
	
def copy_preserve(src, dst):
	echo('cp -p %s %s', src, dst)
	shutil.copy2(src, dst)

def copy_recursive(src, dst):
	echo('cp -Rp %s %s', src, dst)
	cmd = 'cp -Rp %s %s' % (src, dst)
	if not shell_command(cmd):
		fail('Failed to %s', cmd)

def make_tar_bz2(archive_fname, src):
	echo('tar cfj %s %s', archive_fname, src)
	cmd = 'tar cfj "%s" "%s"' % (archive_fname, src)
	if not shell_command(cmd):
		fail('Failed to %s', cmd)

def shrink_directory(dir_path, shrink_fname):
	cwd = DirectorySentinel(dir_path)
	try:
		echo('In directory %s', os.getcwd())
		with open(shrink_fname) as fp:
			for line in fp:
				line = line.strip()
				if line == '':
					log('Skipping empty line')
				elif line[0] == '#':
					log('Skipping comment line "%s"', line)
				elif os.path.isfile(line) or os.path.isdir(line):
					echo(' - %s', line)
					#os.unlink(line)
	finally:
		cwd.restore()
	print

def make_zip(archive_fname, base_dir, *dirs):
	cwd = DirectorySentinel(base_dir)
	try:
		echo('In directory %s', os.getcwd())
		if os.path.isfile(archive_fname):
			echo('Removing existing archive %s', archive_fname)
			os.unlink(archive_fname)
		cmd = 'zip -rq9T "%s" %s' % (archive_fname, ' '.join(dirs))
		echo('Will zip with command string "%s"', cmd)
		if not shell_command(cmd):
			fail('Failed to %s', cmd)
	finally:
		cwd.restore()
	print

def delete_directory_files_by_extension(basedir, file_ext):
	for root, dirs, files in os.walk(basedir):
		log(' in dir %s', root)
		for f in files:
			fpath = os.path.join(root, f)
			if os.path.isfile(fpath):
				if fpath.endswith(file_ext):
					echo('unlink %s', fpath)
					os.unlink(fpath)

def replicate_directory_tree(dst_base, src_base):
	log('Replicating in %s directory hierarchy from %s', dst_base, src_base)
	for root, dirs, files in os.walk(src_base):
		log(' in srcdir %s', root)
		pref = os.path.commonprefix([src_base, root])
		delta = root[len(pref)+1:]
		log(' delta %s', delta)
		for d in dirs:
			subd = os.path.join(delta, d)
			dstd = os.path.join(dst_base, subd)
			echo('  mkdir %s', dstd)
			os.mkdir(dstd)
			os.chmod(dstd, 0755)

# -------------------------------------------------------------------
# Define some useful variables.
# -------------------------------------------------------------------

dist_files = [dist_moin, dist_twisted, dist_libarchive]

for fn in dist_files:
	if not os.path.isfile(fn):
		fail('Required file %s is missing.\nCheck your configuration.', fn)

# Ensure the current directory contains a subdirectory named MoinX.xcodeproj
# i.e. the script is called from the project base directory.
if not os.path.isdir('MoinX.xcodeproj'):
    fail('Script must be called from the project root directory')        

# We now define a set of variables which simplify path construction
base = os.getcwd()
patch_dir = os.path.join(base, 'patches')
generated = os.path.join(base, 'generated')
build_dir = os.path.join(generated, 'build')
src_dir = os.path.join(build_dir, 'src')
out_dir = os.path.join(generated, 'WikiBootstrap')
log_dir = os.path.join(build_dir, 'log')

# MoinX stuff
instance_name = 'instance'
instance_default = os.path.join(out_dir, instance_name)
instance_default_archive = os.path.join(out_dir, instance_name + '.tar.bz2')
bin_dir = os.path.join(out_dir, 'bin')
python_lib_dir = os.path.join(out_dir, 'pythonlib')
python_aux_lib_dir = os.path.join(out_dir, 'pythonlib-aux')
python_aux_lib_dir_readme = os.path.join(base, 'scripts/README.python')

htdocs_dir = out_dir # source directory is a htdocs dir
python_run_dir = os.path.join(out_dir, 'pyrun')

# Moin stuff
moin_source = os.path.join(src_dir, moin_release)
moin_install_log = os.path.join(log_dir, 'moin-install.log')
moin_base_dir = os.path.join(build_dir, 'share/moin')
moin_license = os.path.join(moin_source, 'docs/licenses/COPYING')

# Generic
python_version = '%d.%d' % (sys.version_info[0], sys.version_info[1])

python_local_packages_install_dir = os.path.join(os.path.join(os.path.join(build_dir, 'lib'),
                                                              'python%s' % python_version),
                                                 'site-packages')

# Twisted stuff
twisted_source = os.path.join(src_dir, twisted_release)
twisted_license = os.path.join(twisted_source, 'LICENSE')
twisted_zope_interface_source = os.path.join(twisted_source, twisted_zope_interface_release)
twisted_zope_interface_install_log = os.path.join(log_dir, 'twisted-zope-interface-install.log')
twisted_core_source = os.path.join(twisted_source, twisted_core_release)
twisted_core_install_log = os.path.join(log_dir, 'twisted-core-install.log')
twisted_web_source = os.path.join(twisted_source, twisted_web_release)
twisted_web_install_log = os.path.join(log_dir, 'twisted-web-install.log')

# libarchive stuff
libarchive_source = os.path.join(src_dir, libarchive_release)
libarchive_license = os.path.join(libarchive_source, 'COPYING')
libarchive_configure_log = os.path.join(log_dir, 'libarchive-configure.log')
libarchive_make_log = os.path.join(log_dir, 'libarchive-make.log')
libarchive_make_install_log = os.path.join(log_dir, 'libarchive-make-install.log')

# shrink files
zope_shrink_file = os.path.join(base, 'scripts/zope-shrink-file.txt')
twisted_shrink_file = os.path.join(base, 'scripts/twisted-shrink-file.txt')
moinmoin_shrink_file = os.path.join(base, 'scripts/moinmoin-shrink-file.txt')

# After installing twisted, locate the directory name of zope.interface
# within the 'twisted' directory which has been installed.
def post_build_find_installed_zope_interface_subdir_name():
	# Mac OS X 10.5 Leopard includes twisted and twisted/zope.interface
	# We ignore this fact and want to find out the real directory name
	# of zope.interface installed in our `python_lib_dir'.
	#
	# Basically we do this and grep for zope.interface:
	# PYTHONPATH=`pwd`/pythonlib python -c 'import sys; print "\n".join(sys.path)'
	zope_interface_subdir_name = None
	cwd = DirectorySentinel(python_lib_dir)
	echo('Changed directory to %s', os.getcwd())
	try:
		env = EnvironmentSentinel({'PYTHONPATH': os.getcwd()})
		echo('Added %s into PYTHONPATH', os.getcwd())
		try:
			cmd = "python -c \"import sys; print '\\n'.join(sys.path)\""
			syspath = system_output(cmd)
			if syspath is not False:
				for path in syspath:
					path = path.strip()
					if re.match(r'.*/zope\.interface[^/]*$', path):
						zope_interface_subdir_name = os.path.basename(path)
						break
		finally:
			env.restore()
	finally:
		cwd.restore()
	if zope_interface_subdir_name is None:
		fail('Cannot deduce zope.interface real directory name in "python_lib_dir"')
	return zope_interface_subdir_name

# -------------------------------------------------------------------
# Prepare
# -------------------------------------------------------------------

def prepare():
	echo('*** cleaning up possible pre existing build hierachy')
	remove_directories([generated, build_dir, out_dir])
	print
	
	echo('*** creating build infrastructure...')
	make_directories([generated,
					  build_dir,
					  src_dir,
					  out_dir,
					  log_dir,
					  bin_dir,
					  python_lib_dir,
					  python_aux_lib_dir,
					  htdocs_dir,
					  python_run_dir,
					  instance_default])
	print
	
	os.environ['DYLD_FALLBACK_LIBRARY_PATH'] = '' # for safety
	os.environ['PYTHONPATH'] = python_local_packages_install_dir
	echo('*** set environment')
	echo('... Python version %s', python_version)
	echo('... PYTHONPATH %s', os.environ['PYTHONPATH'])
	print
	
	echo('*** unpacking distribution files...')
	cwd = DirectorySentinel(src_dir)
	try:
		for dfile in dist_files:
			extract_archive(dfile)
	finally:
		cwd.restore()
	print
	
	echo('*** patching sources...')
	for patch_file in glob.glob('%s/*.patch' % patch_dir):
		cmd = 'patch -p1 < "%s"' % os.path.join(patch_dir, patch_file)
		cwd = DirectorySentinel(src_dir)
		try:
			echo('... in directory: %s', os.getcwd())
			if not shell_command(cmd):
				fail('Failed to patch with cmd "%s"', cmd)
		finally:
			cwd.restore()
	print

# -------------------------------------------------------------------
# Build
# -------------------------------------------------------------------

def build():
	run_python_install('moin',
					   build_dir,
					   moin_source,
					   moin_install_log,
					   quiet=True,
					   silent_stdout=False)	
	
	run_python_install('twisted/zope-interface',
					   build_dir,
					   twisted_zope_interface_source,
					   twisted_zope_interface_install_log,
					   quiet=True,
					   silent_stdout=False)
	
	run_python_install('twisted/core',
					   build_dir,
					   twisted_core_source,
					   twisted_core_install_log,
					   quiet=False,
					   silent_stdout=True)
	
	run_python_install('twisted/web',
					   build_dir,
					   twisted_web_source,
					   twisted_web_install_log,
					   quiet=False,
					   silent_stdout=True)
	
	run_make_c_package('libarchie',
					   'configure',
					   build_dir,
					   libarchive_source,
					   libarchive_configure_log,
					   './configure --prefix %s %s >%s',
					   args=(build_dir,
							 universal_binary_configure_args,
							 libarchive_configure_log),
					   envd={'CFLAGS': universal_binary_cflags})
	
	run_make_c_package('libarchive',
					   'make',
					    build_dir,
					    libarchive_source,
					    libarchive_make_log,
					    'make >%s',
					    args=('/dev/null'))
	
	run_make_c_package('libarchive',
					   'make install',
					    build_dir,
					    libarchive_source,
					    libarchive_make_install_log,
					    'make install >%s',
					    args=('/dev/null'))

# -------------------------------------------------------------------
# Assemble
# -------------------------------------------------------------------

def asm_copy():
	echo('*** assemblying')
	cwd = DirectorySentinel(generated)
	try:
		copy_preserve(os.path.join(build_dir, 'bin/twistd'), bin_dir)
		copy_recursive(os.path.join(python_local_packages_install_dir, '*'), python_lib_dir)
		copy_recursive(os.path.join(build_dir, 'share/moin/htdocs'), htdocs_dir)
	finally:
		cwd.restore()

	cwd = DirectorySentinel(base)
	try:
		copy_recursive('python/*.py', python_run_dir)
		copy_recursive(os.path.join(build_dir, 'share/moin/data'), instance_default)
		copy_recursive(os.path.join(build_dir, 'share/moin/underlay'), instance_default)
	finally:
		cwd.restore()

def asm_moinmoin_instance_tar():
	cwd = DirectorySentinel(out_dir)
	try:
		make_tar_bz2(os.path.basename(instance_default_archive),
		             os.path.basename(instance_name))
		remove_directories([instance_name])
		copy_preserve(moin_license, os.path.join(out_dir, 'LICENSE.MoinMoin'))
		copy_preserve(twisted_license, os.path.join(out_dir, 'LICENSE.Twisted'))
		copy_preserve(libarchive_license, os.path.join(out_dir, 'COPYING.libarchive'))
	finally:
		cwd.restore()

def asm_purge_dylibs():
	# remove everything except *.lib, because xcode prefers *.dylib regardless
	# of what was added to `Frameworks'.
	delete_directory_files_by_extension(os.path.join(build_dir, 'lib'), '.dylib')

def asm_make_status_menuicon():
	cwd = DirectorySentinel(base)
	try:
		cmd = 'tiffutil -cat Icons/MoinX_16.tif -out "%s"' % \
			os.path.join(base, 'MoinX_statusmenuicon.tif')
		if not shell_command(cmd):
			fail('Failed to build MoinX statusmenu icon')
	finally:
		cwd.restore()



def asm_shrink():
	echo('*** shrinking')
	zope_interface_subdir_name = post_build_find_installed_zope_interface_subdir_name()
	shrink_directory(os.path.join(python_lib_dir, zope_interface_subdir_name),
	 				 zope_shrink_file)
	shrink_directory(os.path.join(python_lib_dir, 'twisted'),
					 twisted_shrink_file)
	shrink_directory(os.path.join(python_lib_dir, 'MoinMoin'),
				     moinmoin_shrink_file)
	print

def asm_pythonlib_zip():
	echo('*** creating zip out of pythonlib')
	zope_interface_subdir_name = post_build_find_installed_zope_interface_subdir_name()
	make_zip(os.path.join(out_dir, 'pythonlib.zip'), python_lib_dir, 
		zope_interface_subdir_name, 'twisted', 'MoinMoin')
	print
	
def asm_replicate_moinmoin_dir():
	echo('*** duplicating moinmoin pythonlib hierarchy in %s',
	 	 os.path.basename(python_aux_lib_dir))
	dst = os.path.join(python_aux_lib_dir, 'MoinMoin')
	if os.path.isdir(dst):
		shutil.rmtree(dst)
	os.mkdir(dst)
	replicate_directory_tree(dst, os.path.join(python_lib_dir, 'MoinMoin'))
	copy_preserve(python_aux_lib_dir_readme, python_aux_lib_dir)
	shutil.rmtree(python_lib_dir) # we use the zip and/or python-aux-lib-dir
	print

def assemble():
	asm_copy()
	asm_moinmoin_instance_tar()
	asm_purge_dylibs()
	asm_make_status_menuicon()
	asm_shrink()
	asm_pythonlib_zip()
	asm_replicate_moinmoin_dir()

def doall():
	prepare()
	build()
	assemble()

if __name__ == '__main__':
	cmds = {'prepare': prepare, 'build': build, 'assemble': assemble, 'all': doall}
	argv = sys.argv[1:]
	if (len(argv)) == 0:
		argv.append('all')
	if not set(argv).issubset(set(cmds.keys())):
		print >>sys.stderr, 'Unknown kommand "%s"! Valid commands are %s' \
			% (cmd, ', '.join(commands.keys()))
	map(lambda c: cmds[c](), argv)
	echo("""
******************************************************************
                 NOW FIRE UP XCode and build
******************************************************************
""")		
# EOF