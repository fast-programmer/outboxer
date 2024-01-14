# require './lib/outboxer'

# require 'spec_helper'

# module Outboxer
#   RSpec.describe Publisher do
#     describe '.connect!' do
#       before(:all) { Publisher.disconnect! }

#       after(:all) do
#         db_config = {
#           'adapter' => 'postgresql',
#           'username' => `whoami`.strip,
#           'database' => 'outboxer_test'
#         }

#         Publisher.connect!(db_config: db_config)
#       end

#       context 'when db config not valid' do
#         let(:db_config) do
#           {
#             'adapter' => 'postgresql',
#             'username' => 'bad',
#             'database' => 'outboxer_test'
#           }
#         end

#         it 'establishes a connection without errors' do
#           expect do
#             Publisher.connect!(db_config: db_config)
#           end.to raise_error(Publisher::ConnectError, /There is an issue connecting/)
#         end

#         it 'does not connect to the database' do
#           begin
#             Publisher.connect!(db_config: db_config)
#           rescue Publisher::ConnectError
#             # ignore
#           end

#           expect(Publisher.connected?).to be false
#         end
#       end

#       context 'when db config valid' do
#         let(:db_config) do
#           {
#             'adapter' => 'postgresql',
#             'username' => `whoami`.strip,
#             'database' => 'outboxer_test'
#           }
#         end

#         it 'establishes a connection without errors' do
#           expect { Publisher.connect!(db_config: db_config) }.not_to raise_error
#         end

#         it 'actually connects to the database' do
#           Publisher.connect!(db_config: db_config)

#           expect(Publisher.connected?).to be true
#         end
#       end
#     end
#   end
# end
