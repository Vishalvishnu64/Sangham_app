require('dotenv').config();
const mongoose = require('mongoose');
const User = require('./models/User');
const Transaction = require('./models/Transaction');
const Attendance = require('./models/Attendance');

const memberNames = [
  'Lakshmi Devi', 'Padma Rani', 'Sarada Kumari', 'Vijaya Lakshmi', 'Rani Devi',
  'Kavitha Sharma', 'Sunitha Bai', 'Anitha Kumari', 'Radha Devi', 'Meena Kumari'
];

async function seed() {
  try {
    await mongoose.connect(process.env.MONGO_URI);
    console.log('Connected to MongoDB');

    // Clear existing data
    await User.deleteMany({});
    await Transaction.deleteMany({});
    await Attendance.deleteMany({});

    // Create admin
    const admin = await User.create({
      name: 'Sangham Admin',
      phone: '9999999999',
      password: 'admin123',
      role: 'admin'
    });
    console.log('✅ Admin created: phone=9999999999, password=admin123');

    // Create members
    const members = [];
    for (let i = 0; i < memberNames.length; i++) {
      const phone = `98765${String(i).padStart(5, '0')}`;
      const member = await User.create({
        name: memberNames[i],
        phone,
        password: phone.slice(-4), // Last 4 digits as password
        role: 'user'
      });
      members.push(member);
      console.log(`✅ Member: ${member.name} (${phone}, pwd: ${phone.slice(-4)})`);
    }

    // Create sample transactions (12 weeks of contributions)
    const transactions = [];
    for (let week = 0; week < 12; week++) {
      const date = new Date();
      date.setDate(date.getDate() - (week * 7));

      for (const member of members) {
        // ~80% chance of having contributed each week
        if (Math.random() < 0.8) {
          transactions.push({
            userId: member._id,
            amount: 100,
            type: 'contribution',
            note: 'Weekly contribution',
            date,
            createdBy: admin._id
          });
        }
      }
    }
    await Transaction.insertMany(transactions);
    console.log(`✅ Created ${transactions.length} transactions`);

    // Create sample attendance (last 30 days)
    const attendanceRecords = [];
    for (let day = 0; day < 30; day++) {
      const date = new Date();
      date.setDate(date.getDate() - day);
      date.setHours(0, 0, 0, 0);

      // Only mark attendance on some days (simulating weekly meetings)
      if (day % 7 === 0) {
        for (const member of members) {
          attendanceRecords.push({
            userId: member._id,
            date,
            status: Math.random() < 0.85 ? 'present' : 'absent',
            markedBy: admin._id
          });
        }
      }
    }
    await Attendance.insertMany(attendanceRecords);
    console.log(`✅ Created ${attendanceRecords.length} attendance records`);

    console.log('\n🎉 Seed completed successfully!');
    console.log('Admin login: phone=9999999999, password=admin123');
    console.log('User login: phone=9876500000, password=0000');

    process.exit(0);
  } catch (error) {
    console.error('❌ Seed error:', error.message);
    process.exit(1);
  }
}

seed();
