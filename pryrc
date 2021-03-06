# coding:utf-8 vim:ft=ruby

Pry.config.pager = true
Pry.config.color = true
Pry.config.history.should_save = true

# wrap ANSI codes so Readline knows where the prompt ends
def colour(name, text)
  if Pry.color
    "\001#{Pry::Helpers::Text.send name, '{text}'}\002".sub '{text}', "\002#{text}\001"
  else
    text
  end
end

# pretty prompt
Pry.config.prompt = [
  proc { |target_self, nest_level, pry|
    prompt = colour :bright_black, Pry.view_clip(target_self)
    prompt += ":#{nest_level}" if nest_level > 0
    prompt += colour :cyan, ' » '
  },
  proc { |target_self, nest_level, pry|
    colour :red, '?> '
  }
]

# tell Readline when the window resizes
old_winch = trap 'WINCH' do
  if `stty size` =~ /\A(\d+) (\d+)\n\z/
    Readline.set_screen_size $1.to_i, $2.to_i
  end
  old_winch.call unless old_winch.nil?
end

# use awesome print for output if available
org_print = Pry.config.print
Pry.config.print = proc do |output, value|
  begin
    require 'awesome_print'
    output.puts value.ai
  rescue LoadError => err
    org_print.call(output, value)
  end
end

# startup hooks
org_hook = Pry.hooks[:before_session]
Pry.hooks[:before_session] = proc do |output, target, pry|
  org_hook.call output, target, pry

  # show ActiveRecord SQL queries in the console
  if defined? ActiveRecord
    ActiveRecord::Base.logger = Logger.new STDOUT
  end

  # load Rails console commands
  if defined?(Rails) && Rails.env
    if Rails::VERSION::MAJOR >= 3
      require 'rails/console/app'
      require 'rails/console/helpers'
      if Rails.const_defined? :ConsoleMethods
        extend Rails::ConsoleMethods
      end
    else
      require 'console_app'
      require 'console_with_helpers'
    end
  end
end
