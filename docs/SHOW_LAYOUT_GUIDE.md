# Apply a show to another layout

1. Open the source show. Choose **File → Layout Roles**, create roles such as **Roof**, **Windows**, or **Front Lights**, and add the relevant targets. You can add a fixture group at once, place a target in several roles, and reorder the members of each role. Save the show.
2. Open the receiving layout, or create a show from one of your Playgrounds. Add the same role names and assign them to this layout’s targets. Save the roles. Roles also travel with a saved Playground.
3. Choose **File → Apply Show to This Layout** and select the saved source show. Check the proposed destinations. Matching uses shared role names and member order, with existing target identities and unique names as fallbacks. A single source can drive multiple compatible destinations. Choose or explicitly skip each unresolved target.
4. Choose **Save Show Copy** and give the new project a filename. Choose **Open Copy** to open it through the ordinary project workflow.

The copy uses the receiving layout’s surface corners, input maps, masks, object memberships, reference photo, output selection, and fixture patch. It uses the source show’s soundtrack, timeline clips, palette and preset libraries, markers, mapped layers and regions, lighting cues, looks, moving-head paths, and choreography. Project files are saved independently. For connected objects, match the shared object first and assign any separately programmed faces within the receiving object.

The order of a role determines how multiple compatible targets are matched. When a chase gains or loses targets, its interval stays the same and its duration can change. The app checks for invalid or overlapping programming before saving.

Build 44 opens earlier project files. Copies and other projects saved in build 44 use project format 17 and require build 44 or newer.
