if get_option('enable_examples')

  example_deps = libghost_deps + [ libghost_dep ]

  executable('hello-ghost', 'hello-ghost-2fa.vala',
    dependencies: example_deps,
    vala_args: [
        '--pkg=posix',
        '--vapidir=' + meson.source_root() + '/vapi'
        ],
    install: false
  )

endif
