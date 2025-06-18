puts "🌍 Добавляем страны..."

[
  {
    title: "Казахстан",
    code: "KZ",
    phone_prefixes: ["+7"],
    is_active: true,
    locale: "ru",
    timezone: "Asia/Almaty",
    position: 1,
    default_currency: "KZT"
  },
  {
    title: "Россия",
    code: "RU",
    phone_prefixes: ["+7"],
    is_active: true,
    locale: "ru",
    timezone: "Europe/Moscow",
    position: 2,
    default_currency: "RUB"
  },
  {
    title: "Беларусь",
    code: "BY",
    phone_prefixes: ["+375"],
    is_active: true,
    locale: "ru",
    timezone: "Europe/Minsk",
    position: 3,
    default_currency: "BYN"
  }
].each do |attrs|
  Country.find_or_initialize_by(code: attrs[:code]).tap do |country|
    country.assign_attributes(attrs)
    country.save!
  end
end

puts "🌍 Создаём тарифные планы..."

AgencyPlan.find_or_create_by!(title: "Пробный") do |plan|
  plan.description = "Бесплатный тариф с базовыми возможностями"
  plan.max_employees = 1
  plan.max_properties = 5
  plan.max_photos = 5
  plan.max_buy_requests = 5
  plan.max_sell_requests = 5
  plan.is_custom = false
  plan.is_active = true
  plan.is_default = true
end

puts "👑 Создаём пользователей по ролям..."

users = [
  {
    phone: "77000000001",
    email: "admin@cloudsquares.local",
    password: "UserPassword1@",
    role: :admin,
    country_code: "RU",
    first_name: "John Doe 1"
  },
  {
    phone: "77000000002",
    email: "admin_manager@cloudsquares.local",
    password: "UserPassword1@",
    role: :admin_manager,
    country_code: "RU",
    first_name: "John Doe 2"
  },
  {
    phone: "77000000003",
    email: "agent_admin@cloudsquares.local",
    password: "UserPassword1@",
    role: :agent_admin,
    country_code: "RU",
    first_name: "John Doe 3"
  },
  {
    phone: "77000000004",
    email: "agent_manager@cloudsquares.local",
    password: "UserPassword1@",
    role: :agent_manager,
    country_code: "RU",
    first_name: "John Doe 4"
  },
  {
    phone: "77000000005",
    email: "agent@cloudsquares.local",
    password: "UserPassword1@",
    role: :agent,
    country_code: "RU",
    first_name: "John Doe 5"
  },
  {
    phone: "77000000006",
    email: "user@cloudsquares.local",
    password: "UserPassword1@",
    role: :user,
    country_code: "RU",
    first_name: "John Doe 6"
  }
]

users.each do |attrs|
  User.find_or_initialize_by(phone: attrs[:phone]).tap do |user|
    user.assign_attributes(
      email: attrs[:email],
      password: attrs[:password],
      password_confirmation: attrs[:password],
      role: attrs[:role],
      country_code: attrs[:country_code],
      is_active: true,
      first_name: attrs[:first_name]
    )
    user.save!
  end
end

# puts "👑 Создаём Категории внутри агентства..."
# agency = Agency.first
#
# %w[Квартира Дом Коммерческая\ недвижимость Земельный\ участок].each_with_index do |title, i|
#   PropertyCategory.create!(
#     agency: agency,
#     title: title,
#     slug: title.parameterize,
#     position: i + 1
#   )
# end

