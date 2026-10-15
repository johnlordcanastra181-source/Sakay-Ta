# Mandatory Final Report

## 1. Explain step-by-step EXACTLY how the passenger's destination changes from their real selection into Chocolate Hills.

The destination was **never** overwritten by a hardcoded fallback during the booking process. The string "Chocolate Hills" does not exist anywhere in the source code. Instead, the bug was caused by a logical flaw in how the app handles active rides during the booking flow:

1. In a previous session or test run, a test booking was made to "Chocolate Hills" (likely chosen from OpenStreetMap results).
2. Because of the driver listener bug (Bug 2), that ride was never received by a driver, never accepted, and therefore never completed or cancelled. It remained stuck in Firestore with a status of `searching`.
3. When testing again, the passenger explicitly searched for and selected a new destination ("TEST DESTINATION X").
4. The passenger pressed "Confirm & Book Ride", which called `AppState.requestTrip()`.
5. Inside `requestTrip()`, the app queried Firestore for any existing active trips for that passenger (`activeTripForPassenger()`).
6. Because the old "Chocolate Hills" ride was still stuck in a `searching` state, Firestore returned it as the `existing` active trip.
7. `requestTrip()` had a flawed check: `if (existing != null) { return existing; }`. Instead of creating the newly requested ride to "TEST DESTINATION X", the app silently aborted the new creation, resurrected the old "Chocolate Hills" ride from the database, and returned it.
8. The UI navigated to the Ride Request screen and correctly displayed the details of the ride it was handed—which was the old "Chocolate Hills" ride.

## 2. What file and line number contained the bug?

The bug was located in **`lib/state/app_state.dart`**, originally around **line 2501** inside the `requestTrip()` method:

```dart
      final existing = await trips.activeTripForPassenger(authUid);
      if (existing != null) {
        activeTrip = existing;
        notifyListeners();
        return existing; // BUG: Silently aborted new ride creation
      }
```
*Note: A similar offline guard block (`else if (activeTrip?.isActive == true) return activeTrip;`) immediately below it was also removed to ensure consistent behavior.*

## 3. Explain the Firebase data flow failure that prevented Driver A from seeing the passenger's request.

The data flow failure was caused by a combination of strict Firestore security rules and Firestore index limitations colliding in the driver's listener query (`streamIncomingRequestsForDriver` in `lib/services/firestore_service.dart`).

1. **The Rule**: The Firestore security rules for the `rides` collection strictly dictate that a driver can only read rides where `driver_id == request.auth.uid` (direct assignment) OR `driver_id == null` (broadcast). 
2. **The Query**: The original query attempted to satisfy this rule and filter for pending rides using:
   `.where('status', isEqualTo: 'searching').where(Filter.or( Filter('driver_id', isEqualTo: driverId), Filter('driver_id', isNull: true) ))`
3. **The Failure**: While this query logically satisfies the security rules, combining an equality filter on one field (`status`) with an `OR` filter on another field (`driver_id`) requires a complex **Composite Index** in Firestore. Because that index was not built (and we are operating under constraints where we cannot build one), Firestore rejected the query entirely and threw a `failed-precondition` exception. 
4. **The Result**: The stream listener instantly crashed with an error, meaning the driver's app never actively listened to the `rides` collection. The driver's screen was permanently stuck waiting for ride requests because the connection was severed by the missing index.

**The Fix:** I restructured the query into two simple, separate streams:
1. `_tripsRef.where('status', isEqualTo: 'searching').where('driver_id', isEqualTo: driverId)`
2. `_tripsRef.where('status', isEqualTo: 'searching').where('driver_id', isNull: true)`

Because multiple simple equality filters rely on Firestore's built-in Zigzag Merge Join algorithm, **no composite index is required**. Both queries natively pass the security rules, execute efficiently, and their results are now safely merged in a `StreamController` and delivered to the driver's UI.
