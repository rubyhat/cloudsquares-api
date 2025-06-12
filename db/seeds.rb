# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

puts "🌍 Добавляем страны..."

Country.create!(
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
  ]
)


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
    country_code: "KZ",
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
  User.find_or_create_by!(phone: attrs[:phone]) do |user|
    user.email = attrs[:email]
    user.password = attrs[:password]
    user.password_confirmation = attrs[:password]
    user.role = attrs[:role]
    user.country_code = attrs[:country_code]
    user.is_active = true
    user.first_name = attrs[:first_name]
  end
end
