# TODO: проверить содержимое тестов и их работоспособность
# использовать FactoryBot
require "rails_helper"

RSpec.describe LimitChecker, type: :service do
  let(:agency_plan) do
    AgencyPlan.create!(
      title: "Test Plan",
      max_employees: 3,
      max_properties: 2,
      max_photos: 5,
      max_buy_requests: 5,
      max_sell_requests: 5,
      is_active: true
    )
  end

  let(:agency) { Agency.create!(title: "Test Agency", slug: "test-agency", agency_plan: agency_plan, is_active: true) }

  describe ".exceeded?" do
    context "when agency has not exceeded the employee limit" do
      before do
        2.times do |i|
          user = User.create!(
            phone: "7000000000#{i + 1}",
            email: "user#{i + 1}@test.com",
            password: "TestPassword1@",
            password_confirmation: "TestPassword1@",
            first_name: "Test",
            country_code: "RU",
            role: :agent
          )
          UserAgency.create!(user: user, agency: agency, is_default: true, status: :active)
        end
      end

      it "returns false" do
        expect(LimitChecker.exceeded?(:employees, agency)).to eq(false)
      end
    end

    context "when agency has reached the employee limit" do
      before do
        3.times do |i|
          user = User.create!(
            phone: "7000000000#{i + 1}",
            email: "user#{i + 1}@test.com",
            password: "TestPassword1@",
            password_confirmation: "TestPassword1@",
            first_name: "Test",
            country_code: "RU",
            role: :agent
          )
          UserAgency.create!(user: user, agency: agency, is_default: true, status: :active)
        end
      end

      it "returns true" do
        expect(LimitChecker.exceeded?(:employees, agency)).to eq(true)
      end
    end

    context "when agency plan has no limits (null)" do
      before { agency_plan.update!(max_employees: nil) }

      it "returns false" do
        expect(LimitChecker.exceeded?(:employees, agency)).to eq(false)
      end
    end

    context "when unknown limit key is passed" do
      it "raises an error" do
        expect {
          LimitChecker.exceeded?(:unknown_limit, agency)
        }.to raise_error(ArgumentError, /Unknown limit key/)
      end
    end

    context "when agency has no plan" do
      before { agency.update!(agency_plan: nil) }

      it "returns false" do
        expect(LimitChecker.exceeded?(:employees, agency)).to eq(false)
      end
    end
  end
end
