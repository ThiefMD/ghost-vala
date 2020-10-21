if get_option('enable_examples')

  example_deps = libghost_deps + [ libghost_dep ]+ [ dependency('gtk+-3.0'), dependency('gtksourceview-3.0'), ]

  executable('hello-ghost', 'hello-ghost.vala',
    dependencies: example_deps,
    vala_args: [
        '--pkg=posix',
        '--vapidir=' + meson.source_root() + '/vapi'
        ],
    install: false
  )

endif
