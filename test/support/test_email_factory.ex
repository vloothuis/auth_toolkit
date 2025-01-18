defmodule AuthToolkit.TestEmailFactory do
  @moduledoc false
  def new do
    Swoosh.Email.from(Swoosh.Email.new(), Faker.Internet.email())
  end
end
