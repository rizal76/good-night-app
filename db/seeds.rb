# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "🌱 Starting database seeding..."

# Create sample users
users_data = [
  { name: "Alice Johnson" },
  { name: "Bob Smith" },
  { name: "Carol Davis" },
  { name: "David Wilson" },
  { name: "Eva Brown" },
  { name: "Frank Miller" },
  { name: "Grace Lee" },
  { name: "Henry Taylor" }
]

puts "👥 Creating users..."
users = users_data.map do |user_data|
  User.find_or_create_by!(name: user_data[:name])
end

puts "✅ Created #{users.count} users"

# Create some follow relationships
puts "🔗 Creating follow relationships..."
follow_relationships = [
  [users[0], users[1]], # Alice follows Bob
  [users[0], users[2]], # Alice follows Carol
  [users[1], users[0]], # Bob follows Alice
  [users[1], users[3]], # Bob follows David
  [users[2], users[0]], # Carol follows Alice
  [users[2], users[4]], # Carol follows Eva
  [users[3], users[1]], # David follows Bob
  [users[3], users[5]], # David follows Frank
  [users[4], users[2]], # Eva follows Carol
  [users[4], users[6]], # Eva follows Grace
  [users[5], users[3]], # Frank follows David
  [users[5], users[7]], # Frank follows Henry
  [users[6], users[4]], # Grace follows Eva
  [users[6], users[0]], # Grace follows Alice
  [users[7], users[5]], # Henry follows Frank
  [users[7], users[1]]  # Henry follows Bob
]

follow_relationships.each do |follower, followed|
  Follow.find_or_create_by!(follower: follower, followed: followed)
end

puts "✅ Created #{follow_relationships.count} follow relationships"

# Create sample sleep records for some users
puts "😴 Creating sample sleep records..."

# Alice - has some completed sleep sessions
alice = users[0]
SleepRecord.find_or_create_by!(
  user: alice,
  clock_in_time: 3.days.ago.beginning_of_day + 22.hours,
  clock_out_time: 2.days.ago.beginning_of_day + 7.hours,
  duration: 9 * 3600 # 9 hours in seconds
)

SleepRecord.find_or_create_by!(
  user: alice,
  clock_in_time: 2.days.ago.beginning_of_day + 23.hours,
  clock_out_time: 1.day.ago.beginning_of_day + 8.hours,
  duration: 9 * 3600 # 9 hours in seconds
)

# Bob - currently clocked in
bob = users[1]
SleepRecord.find_or_create_by!(
  user: bob,
  clock_in_time: 2.hours.ago,
  clock_out_time: nil
)

# Carol - has some sleep history
carol = users[2]
SleepRecord.find_or_create_by!(
  user: carol,
  clock_in_time: 4.days.ago.beginning_of_day + 21.hours,
  clock_out_time: 3.days.ago.beginning_of_day + 6.hours,
  duration: 9 * 3600 # 9 hours in seconds
)

SleepRecord.find_or_create_by!(
  user: carol,
  clock_in_time: 1.day.ago.beginning_of_day + 22.hours,
  clock_out_time: Time.current.beginning_of_day + 7.hours,
  duration: 9 * 3600 # 9 hours in seconds
)

# David - recently clocked out
david = users[3]
SleepRecord.find_or_create_by!(
  user: david,
  clock_in_time: 1.day.ago.beginning_of_day + 23.hours,
  clock_out_time: Time.current.beginning_of_day + 6.hours,
  duration: 7 * 3600 # 7 hours in seconds
)

puts "✅ Created sample sleep records"

puts "🎉 Database seeding completed successfully!"
puts "📊 Summary:"
puts "   - Users: #{User.count}"
puts "   - Follows: #{Follow.count}"
puts "   - Sleep Records: #{SleepRecord.count}"
puts ""
puts "🔍 Sample data created:"
puts "   - Alice Johnson: 2 completed sleep sessions"
puts "   - Bob Smith: Currently clocked in (2 hours ago)"
puts "   - Carol Davis: 2 completed sleep sessions"
puts "   - David Wilson: Recently clocked out (7 hours sleep)"
puts "   - Other users: Ready for sleep tracking"
