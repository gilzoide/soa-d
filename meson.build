project('soa', 'd')

sources = files(
  'source/soa.d',
)
incdir = include_directories('source')

soa = library('soa',
  sources,
  include_directories: incdir,
)

soa_dep = declare_dependency(include_directories: incdir, link_with: soa)
