# finger-string

Finger String is an IOS reminder app that doesn't let you ignore it.

## Reminders

Reminders are just a thing that happens on a day at a time.

The user can include

- Title (required)
- Detailed description (optional)
- Date (required)
- Time (optional)
- Reoccurace rules (optional)

### Reminders Source

Reminders can either be created directly in the app and stored locally or by using an iCal link that the app will read from.

Local reminders should be stored in iCal format so the event logic can be shared across the iCal link and local reminders.

## Reminder Escalation

If you don't mark your reminder as closed it will keep reminding you until you do mark it as closed.

Reminders can escalate from push notifications to full alarms depending on the escalation paths your reminder is using.

For example an escalation path my say you will get:

- A push notification at the time of the reminder
- A push notification 1 hour after the reminder
- An Alarm 1 hour after that
- An Alarm every 30 minutes after that

The escalation path will go on until you either

- Mark the reminder as copmlete
- Snooze the reminder for a given amount of time.

There will be several off-the-shelf escalation paths for the user to choose from, but they can also create their own.

## Closing a reminder

You can close a reminder by either "completing" it or "ignoring" it. Both behave in the same way but they will show the event as ignored (red) or completed (green) in the app so the user can see if they actually addressed it or not.

Once a reminder is closed the escalation path stopps and the user isn't reminded of it anymore.

## Snoozing a Reminder

When a reminder is active, that is, the reminder escalation path has started, the user can snooze the reminder. The app will give the user options of offsets and particular times. Such as

- for 1 hour
- for 3 hours
- until 5:00 pm
- until tomorrow (9:00 am)

And after the snooze option is selected by the user. The escalation path will continue with the last step it was on.

For example: If the escalation path is

- Push notification at reminder time
- Push notification 1 hour later
- Push notification 1 hour later
- Alarm every hour after that

And the user got one push notifiation (step 1) and then another push notification (step 2) and then they pressed snoozed it for 3 hours, then they will get another push notification (step 2) 3 hours later, and then another push notification an hour after that (step 3) followed by alarms every hour after that (step 4). Notice that step 2 happend twice because that is the step that just happened when it was snoozed.

## Editing a reminder

Editing a reminder should work as expected with a couple caviots.

### Editing an iCal link reminder

If you edit a reminder that originates from an iCal link the app should ignore the original iCal event by storing the iCal event id locally as a reminder to ignore. And then just start using a local version of the event instead.

### editing an reminder that is active

Active reminders are reminders who are currently in the an escalation path. If you edit the time of an active reminder the escalation path will be canceled and restarted at the new time.
