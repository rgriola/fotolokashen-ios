### iOS App Purpose

- To be the primary connection to the Company, Project, Photographer, Producers, Crew knowledge base for film, video and digial film management.

- This app should help with the questions for past, present and future productions;
- Where did we set up a production
- How did we set up the production
- What were the challenges and positives of the location
- What resources were easliy to find; could be many items food, bathrooms, parking, camera & lighting equipment rental, travel in and out of the location.
- This is the Physcial part of producing a project
- Allow us to easily connect and share this infomation via text, email and/or slack

###

- Please review our Fotolokashen iOS app file by file and comment into files as needed where business logic may be missing.
- In the review evaluate the coding Architecture, the Swift.view Architecture and styling Architecture. Point out the parts that work and need improvement.
- I want to make feature changes and I believe we need a comprehensive assesment how this app can be better and be ready for more dynamic features;
- A feature update is iOS location creation; iOS needs a photo upload UI Pipeline using iOS Photo Library images + also allowing adding Camera Photos directly. this feature will need a separate implimentation plan as I will use this going forward for another app.
- Any suggestions to make this app stronger.
  -- And place this into a markdown file.

### Features

- plan a slack integration for iOS and Web
- Force user first and last names to be a minimum 3 letters
  - no B E > yes Be En (this may not be their name but we don't do initials. Although I know there are people with 2 letter names. )
- Force user name ie; Richard Griola - first letter of each to be Capitalized. no richard griola > yes Richard Griola


*** task ***
- Create Account in the iOS flow for "create account" the attached UI message to check email did not show up, there was a small toast alert instead. 

-- username should force lowercase letters only and remove space at the end of a username automatically - user does not need to know; this is a common typing issues with users hitting the space bar at the end of their username. 

Date of Birth works much better;  In the Month, Day Year menus scoll the wheel with choice centered in the view port and highlighted, limit the menu to 10 choices at once ie 1980, 1981, 1982, 1983, [1984], 1985, 1986, 1987, 1988, 1989 in this example 1984 is centered and the user can scroll up or down to select the year, one click down would make 1983 centered and the highlighted choice. Apply to Month, Day and Year. 


*** issue *** 
- When the user creates an account starting with iOS, at the point they verify the email through the emailed link, they are redirected back to the web app rather than the iOS app. Is this a simple fix?  So if they create an account on iOS they should be redirected back to the iOS app or through the web app back to the web app. 

... Apr 17 2026
*** Issue *** 
- working on iOS create account flow.
- The attached images show the current UI for the flow in order. The last step "Open fotolokashen app? " should log in the user and skip any more Auth steps. This was found during testing.  