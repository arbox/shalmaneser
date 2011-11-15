module FunctionalTestHelper
  # Run an external process for functional testing and check the return code.
  # <system> returns <true> if the external code exposes no errors.
  # <@msg> is defined for every test object.
  def execute(cmd)
    status = system(cmd)
    assert(status, @msg)
  end
end
