AparCar MVP — Fuengirola Pilot Boundary Document

Last updated: June 2026
What AparCar does in one sentence

A driver leaving a parking spot signals their departure with an estimated timer. Drivers looking for parking receive a real-time notification when a spot is about to become free within their chosen radius.
The two user flows — nothing else exists in v1
Leaving flow:

Driver opens app → taps "I'm leaving" → sets approximate departure timer → can adjust timer in real-time → signal is broadcast to nearby looking drivers
Looking flow:

Driver opens app → taps "I'm looking" → sets search radius → minimizes app → receives push notification when a spot is about to free up nearby
Pilot scope — hard numbers

Target city: Fuengirola, Spain
Target users: 100–500 drivers
Target parking coverage: 500–1,000 spots
Pilot duration: 1 month

Success condition

The pilot succeeds if 50 drivers actively use the app within the first month.
What is explicitly out of scope for v1

Premium features of any kind
Payment processing
Reserved parking spots
Private parking lot integration
In-app maps or navigation
User accounts beyond minimum auth
Driver ratings or history
Gamification
Anything requiring a business partnership before launch

The core technical loop that must work

Leave signal → backend → push notification to looking driver within 30 seconds
If this loop is unreliable, nothing else matters.
Architecture that serves this loop

AppSync (leave/look signals) → Lambda → EventBridge → Redis GEOSEARCH (radius matching) → Pinpoint (push notification)
Everything Pietro builds in AWS must serve this loop first.
