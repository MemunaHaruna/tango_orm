require 'spec_helper'

RSpec.describe TangoOrm::DB do
  before do
    connection_pool = instance_double(TangoOrm::ConnectionPool)
  end

  it "has a version number" do
    expect(TangoOrm::VERSION).not_to be nil
  end
end
