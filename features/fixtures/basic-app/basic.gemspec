Gem::Specification.new do |s|
  s.name         = 'basic'
  s.version      = '0.0.0'
  s.authors      = ['Basic']
  s.summary      = 'Test gemspec for moonshot.'
  s.files        = Dir['Gemfile*', 'Rakefile', '*.gemspec', '*.md', '*.raml',
                       '*.ru', '*.yml',
                       '{bin,config,db,doc,lib,schema,script}/**/*']
  s.require_path = 'lib'
  s.bindir       = 'bin'
  s.executables = Dir['bin/*'].map { |f| File.basename(f) }
end
