#!/system/bin/sh
# Inject test refund SMS messages into SMS inbox
TS=$(date +%s%3N)

content insert --uri content://sms/inbox \
  --bind address:s:AM-AMAZON \
  --bind body:s:"Your refund of Rs 499 for order 405-1234567 has been initiated and will be credited to your account within 3-5 business days" \
  --bind date:l:$TS \
  --bind read:i:1 \
  --bind type:i:1
echo "1 Amazon inserted"

TS=$((TS - 3600000))
content insert --uri content://sms/inbox \
  --bind address:s:FK-FLIPKART \
  --bind body:s:"Flipkart refund processed. Rs 899 will be credited to your payment method for return order RT78901. Expected within 5-7 business days" \
  --bind date:l:$TS \
  --bind read:i:1 \
  --bind type:i:1
echo "2 Flipkart inserted"

TS=$((TS - 3600000))
content insert --uri content://sms/inbox \
  --bind address:s:ZM-ZOMATO \
  --bind body:s:"Your refund of Rs 250 has been initiated for zomato order 1234567. Amount will be credited within 5-7 business days" \
  --bind date:l:$TS \
  --bind read:i:1 \
  --bind type:i:1
echo "3 Zomato inserted"

TS=$((TS - 3600000))
content insert --uri content://sms/inbox \
  --bind address:s:IRCTC \
  --bind body:s:"Refund of Rs 1450 initiated for IRCTC train booking PNR 6789012345. Amount will be credited within 7 working days" \
  --bind date:l:$TS \
  --bind read:i:1 \
  --bind type:i:1
echo "4 IRCTC inserted"

TS=$((TS - 3600000))
content insert --uri content://sms/inbox \
  --bind address:s:CROMA \
  --bind body:s:"Your return has been processed. Refund of Rs 3299 for electronics order CR8823 will be credited to your account within 5 days" \
  --bind date:l:$TS \
  --bind read:i:1 \
  --bind type:i:1
echo "5 Croma inserted"

TS=$((TS - 3600000))
content insert --uri content://sms/inbox \
  --bind address:s:BMS-BOOKMYSHOW \
  --bind body:s:"Refund initiated for your movie ticket cancellation. Amount Rs 350 for reference BMS3301 will be credited within 7 business days" \
  --bind date:l:$TS \
  --bind read:i:1 \
  --bind type:i:1
echo "6 BookMyShow inserted"

echo "All refund SMS injected successfully"
