if get_option('shared_lib')
  libtype = 'shared_library'
else
  libtype = 'static_library'
endif

libghost_sources = [
  'Ghost3.vala'
]


confh = configuration_data ()
confh.set_quoted('PACKAGE_LOCALE_DIR', join_paths(get_option('prefix'), get_option('datadir'), 'locale'))
confh.set_quoted('GETTEXT_PACKAGE', 'ghost')
confh.set_quoted('VERSION', meson.project_version())
configure_file(output : 'config.h',
  configuration : confh)

inc_libh = include_directories ('.')
inc_libh_dep = declare_dependency (include_directories : inc_libh)

libghost = build_target('ghost',
    sources: libghost_sources,
    dependencies: libghost_deps,
    vala_args: [
        '--pkg=posix',
        '--vapidir=' + meson.source_root() + '/vapi'
        ],
    target_type: libtype,
    vala_header: 'ghost.h',
    vala_vapi: 'ghost.vapi',
    c_args: [ '-include', meson.current_build_dir() + '/config.h', '-w'],
    install_dir: [true, true, true],
    install: true,
)

libghost_dep = declare_dependency(
  include_directories: include_directories('.'),
            link_with: libghost,
)

pkg = import('pkgconfig')
pkg.generate(
    libraries: libghost,
      version: meson.project_version(),
         name: 'ghost',
  description: 'Publish to Ghost.',
)
