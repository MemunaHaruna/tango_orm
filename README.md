# TangoOrm
Tango is a lightweight object-relational mapper for small Ruby applications.

## Status

Tango is still in active development and not to be used in production applications.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'tango_orm'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install tango_orm

## Usage

Tango assumes there is a `database.yml` file in a config folder in the root of your project. This file is used to setup your database connection. The `APP_ENV` environment variable is used to select the appropriate configuration for each environment. `development` config will be used by default if `APP_ENV` is not set.

Example `config/database.yml` file:
```
development:
  database: school_development
  username:
  password:
  host: localhost
  port: 5432
```

Afterwards, you can add ORM capabilities to your models by inheriting from `TangoOrm::Model` e.g:

Example model:
```ruby
require 'tango_orm'

class Student < TangoOrm::Model
end
```

Creating the corresponding table for each model is a manual process. I recommend creating makeshift migration files for this.

```ruby
# create table: students

Student.create_table(first_name: "text, not_null", last_name: "text, not_null", age: "integer", start_date: "date", graduation_date: "date", identification_number: "text, unique, not_null")

pp Student.columns
```

### Managing records

```ruby
student = Student.new(first_name: "Chinedu", last_name: "Daniel", identification_number: "OPPOPG001", age: 28)
pp student.save

student = Student.create(first_name: "Iron", last_name: "Bars", start_date: Date.today, identification_number: "XOXO007")
pp student.id
pp student.first_name
pp student.last_name
pp Student.all

# student = Student.find_by_id(2)
# pp student

# student.first_name = "Baby"
# pp student.update
```

## Limitations
- Tango is still in active development and not to be used in production applications.
- Currently only supports Postgres databases.
- There is no support for migrations.
- Several helpful query methods such as `where`, `find`, `find_by`, `first` etc have not been implemented.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment. Alternatively, run `bundler console`.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/MemunaHaruna/tango_orm.

# To do
- Write tests
- Helpful methods (destroy, where, find, find_by, first, last, order, limit, destroy, update_or_create, update_all, destroy_all, changed?, valid?, persisted? save!, find!)
- associations
- migrations
- support for other DBs other than Postgres
- eager loading
- lazy loading
- automatically saved created_at & updated_at fields
- concurrency & thread safety
- connection pooling
- transactions
- dirty tracking (only save the fields that actually changed)
- prepared statements, stored procedures, two-phase commit, transaction isolation, master/slave configurations, and database sharding
- validations

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
