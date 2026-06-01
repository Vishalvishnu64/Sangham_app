require('dotenv').config();
const mongoose = require('mongoose');
const Loan = require('../models/Loan');
const { calculateMonthlyInterest } = require('../utils/loanInterest');

mongoose.connect(process.env.MONGO_URI || 'mongodb+srv://vishalvishnu64:HX63KhLXb7l64Qj5@cluster0.xoito79.mongodb.net/sangham')
  .then(async () => {
    console.log('✅ Connected to MongoDB');
    
    try {
      // Find all active loans
      const activeLoans = await Loan.find({ status: 'active' });
      console.log(`\n📊 Found ${activeLoans.length} active loans`);
      
      let updated = 0;
      
      for (let loan of activeLoans) {
        // Initialize interest fields if not already set
        if (!loan.principalAmount) {
          loan.principalAmount = loan.amount || loan.remainingPrincipal || 0;
        }
        if (!loan.remainingPrincipal) {
          loan.remainingPrincipal = loan.principalAmount;
        }
        // If interest is missing or zero, calculate based on remaining principal
        if (!loan.currentMonthInterest || loan.currentMonthInterest <= 0) {
          loan.currentMonthInterest = calculateMonthlyInterest(loan.remainingPrincipal);
        }
        if (loan.totalInterestPaid === undefined) {
          loan.totalInterestPaid = 0;
        }
        if (!loan.outstandingBalance) {
          loan.outstandingBalance = loan.remainingPrincipal + (loan.currentMonthInterest || 0);
        }
        if (!loan.interestRate) {
          loan.interestRate = 0.01; // 1% per month
        }
        if (!loan.interestCalculatedDate) {
          loan.interestCalculatedDate = new Date();
        }
        
        await loan.save();
        updated++;
        
        console.log(`✅ Updated: Loan ${loan._id.toString().slice(-8)}`);
        console.log(`   Principal: ₹${loan.principalAmount}`);
        console.log(`   Interest: ₹${loan.currentMonthInterest}`);
        console.log(`   Outstanding: ₹${loan.outstandingBalance}`);
      }
      
      console.log(`\n✅ Interest initialized for ${updated} loans`);
    } catch (err) {
      console.error('❌ Error:', err.message);
    }
    
    mongoose.connection.close();
  })
  .catch(err => {
    console.error('❌ Connection error:', err.message);
    process.exit(1);
  });
