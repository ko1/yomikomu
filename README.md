# Yomikomu

* `yomikomu` gem enables to load compiled instruction sequences (bytecodes).
* `kakidasu` command compiles and stores compiled instruction sequences (bytecodes).

This gem requires Ruby 2.3.0.
Most of code is ported from `ruby/sample/iseq_load.rb`.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'yomikomu'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install yomikomu

## Usage

### Configuration

You can use the following configuration with environment variables.

* YOMIKOMU_STORAGE (default: fs): choose storage type.
  * 'fs' (default) stores binaries in the same directory (for examlple, `x.rb` will be compiled to `x.rb.yarb` in the same directory).
  * 'fs2' stores binaries in specific directory.
  * 'fsgz' stores files same as 'fs', but gz compressed.
  * 'fs2gz' stores files same as 'fs2', but gz compressed.
  * 'dbm' stores binaries using dbm
  * 'flatfile' stores binaries in one flat file. Updating is not supported. Use with YOMIKOMU_AUTO_COMPILE.
* YOMIKOMU_STORAGE_DIR (default: "~/.ruby_binaries"): choose directory where binary files are stored.
* YOMIKOMU_AUTO_COMPILE (default: false): if this value is `true`, then compile all required scripts implicitly.
* YOMIKOMU_INFO (default: not defaind): show some information.
* YOMIKOMU_DEBUG (default: not defined): show many information.

### Compile and store instruction sequences

You only need to use the following command.

```
$ kakidasu [file or dir] ...
```

Compile specified file or files (*.rb) in specified directory.
If no files or directories are specified, then use "libdir" of installed Ruby.

### Load compiled binary

You only need to require `yomikomu`.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ko1/yomikomu.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

