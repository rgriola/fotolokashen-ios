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

...  
Create Account flow:
User already has account >> redirect to login in iOS case redirect back to app for login.

...
*** Task ***
- The iOS app sign in view goes to safari for login, and the page appears to try to repeatedly reload, or login in a loop. This also happend with the create account flow. 
- The page opens to fotolokashen.com but repeats. 

*** Task ***
- I want to improve the Capture Function. 
- Currenly a user can create a location with the camera, one photo only I believe or use photos from their library. The later feature does not work well - when I select photos they do not show un the create location panel, the form acts like a separate event. 
- Using the Camera to create a location needs to allow multiple photos from the camera. 
- there is also an issue with a location having multiple photos but over a larger distance. ie I was covering a marching crowd over several miles I took multiple photos, but this would be a same event. If I went back later I could not see the multiple locations within the same event over several miles, one photo would summarize the event. 
- There needs to a way to decipher and check when location had spaced out locations. Creating individual locations for each photo would not work well. 
- can you review the capture funtion in iOS and show me a plan to improve this function. Consider the web app as well since this new approach to locations and photos would need to be applied there as well. 
- do not code just show a plan and what I may have missed. 

... Apr 28 2026 
*** Task ***
- Lets review how the iOS capture process works, the last review pipeline.md does not account for the work we have done to date. 
- There are two workflows 1) ios camera 2) using photo library. 
- We were also trying to add a feature to group photos by distance.  This may be a bit over our skis right now. 
- Lets get the multiple photo capture working first for both Camera and Photo Library. 
- Once this is solid and working we can move onto the Group photos by distance feature.
- remember changing biz logic will affect the web app as well. 
- Come up with a plan from the review for iOS. No coding. 


on iOS Location Details, Can we stucture the address to look like a proper postal address with each line right justifed in the container. 
[30 Hudson Yards]
[5th Floor ]
[New York, NY 10001]
{drop country if user is in that country}

Also default the Permit Required to only appear if Yes. 

On iOS edit view, add a 

*** Task ***
- iOS Capture View has two modes Create a location from the camera, or use photos from your library. 
- lets review how we build a location on iOS with the Camera > Form > Save and Photo Library > Form > Save. 
- my experience is the Photo Library path is slow and buggy. The Camera path is ok but also a little buggy. 
- pipeline.md needs to be updated to reflect the changes we have made to the app, and used as a template for photo uploads. 
- I included Photo Upload Architecture.md for your review as a reference since we are also creating a photo upload path on another app. We do not need auth or the lightroom integration, those are specific to the other app process. 