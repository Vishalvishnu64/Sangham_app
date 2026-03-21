require('dotenv').config();
const mongoose = require('mongoose');
const User = require('./models/User');
const Transaction = require('./models/Transaction');
const Attendance = require('./models/Attendance');

const memberNames = [
  'Lakshmi Devi', 'Padma Rani', 'Sarada Kumari', 'Vijaya Lakshmi', 'Rani Bai'
];

async function seed() {
  try {
    await mongoose.connect(process.env.MONGO_URI);
    console.log('Connected to MongoDB');

    // Get Admin
    const admin = await User.findOne({ role: 'admin' });
    if (!admin) {
      console.log('Admin not found!');
      process.exit(1);
    }

    // Delete non-admin data
    await User.deleteMany({ role: { $ne: 'admin' } });
    await Transaction.deleteMany({});
    await Attendance.deleteMany({});

    // Create 5 members
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
      console.log(`✅ Member: ${member.name} (${phone}, pass: ${phone.slice(-4)})`);
    }

    // Transactions - 4 weeks
    const transactions = [];
    for (let week = 0; week < 4; week++) {
      const date = new Date();
      date.setDate(date.getDate() - (week * 7));

      for (const member of members) {
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

    // Attendance - 4 weeks (1 meeting a week)
    const attendanceRecords = [];
    for (let week = 0; week < 4; week++) {
      const date = new Date();
      date.setDate(date.getDate() - (week * 7));
      date.setHours(0, 0, 0, 0);

      for (const member of members) {
        attendanceRecords.push({
          userId: member._id,
          date,
          status: Math.random() < 0.85 ? 'present' : 'absent',
          markedBy: admin._id
        });
      }
    }
    await Attendance.insertMany(attendanceRecords);
    console.log(`✅ Created ${attendanceRecords.length} attendance records`);

    console.log('\n🎉 Seed completed successfully!');
    process.exit(0);
  } catch (error) {
    console.error('❌ Seed error:', error.message);
    process.exit(1);
  }
}

seed();
