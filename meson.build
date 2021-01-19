project('com.github.lainsce.yishu', ['vala', 'c'], version: '2.0.0')
gnome = import('gnome')
i18n = import('i18n')

add_project_arguments([
		'--target-glib=2.40',
	],
	language: 'vala',
)
add_project_arguments(
    '-DGETTEXT_PACKAGE="@0@"'.format(meson.project_name()),
    language: 'c'
)

asresources = gnome.compile_resources(
    'as-resources', 'data/style.gresource.xml',
    source_dir: 'data',
    c_name: 'as'
)

sources = files(
    'src/Application.vala',
    'src/Task.vala',
    'src/TaskDialog.vala',
    'src/TodoFile.vala',
    'src/SearchEntry.vala',
    'src/MainWindow.vala',
    'src/Preferences.vala',
    'src/Constants/AppSettings.vala',
)

dependencies = [
    dependency('gio-2.0'),
    dependency('gtk+-3.0'),
    dependency('glib-2.0'),
    dependency('gobject-2.0'),
    dependency('gee-0.8'),
    dependency('libhandy-1'),
    dependency('granite')
]

executable(
    meson.project_name(),
    sources,
    asresources,
    dependencies: dependencies,
    install : true
)

subdir('data')
subdir('po')

# Add in a post install script
meson.add_install_script('meson/post_install.py',  join_paths(get_option('prefix'), get_option('datadir')))
