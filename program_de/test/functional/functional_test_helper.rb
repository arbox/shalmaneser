require 'erb'

module FunctionalTestHelper
  # Run an external process for functional testing and check the return code.
  # <system> returns <true> if the external code exposes no errors.
  # <@msg> is defined for every test object.
  def execute(cmd)
    status = system(cmd)
    assert(status, @msg)
  end
  
  # Create a temporary exp file only for this test.
  # Shalmaneser needs absolute paths, we provide them in exp files
  # using templating.
  def create_exp_file(file)
    template = File.read("#{file}.erb")
    text = ERB.new(template).result
    File.open(file, 'w') do |f|
      f.write(text)
    end
  end

  def remove_exp_file(file)
#    File.delete(file)
  end
end
