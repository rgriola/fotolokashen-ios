# Production Date Feature - iOS Implementation Guide

**Feature**: Track filming/production dates for locations  
**Status**: ✅ Backend Complete (February 13, 2026) | 🔄 iOS Pending  
**Backend PR**: Production Date Feature Implementation  

## Overview

The production date feature allows users to track when a location was actually used for filming or production, independent of:
- Photo EXIF dates (when photos were taken)
- Location creation dates (when saved to database)
- Location update dates (last modified)

This is critical for location scouts and production teams who need to track actual filming dates.

---

## Backend Changes (Completed)

### Database Schema
```prisma
model Location {
  // ... existing fields
  productionDate  DateTime?  // NEW: Optional production/filming date
  lastModifiedAt  DateTime?
  createdAt       DateTime   @default(now()) @map("created_at")
  updatedAt       DateTime   @default(now()) @updatedAt @map("updated_at")
}
```

**Field Details:**
- **Type**: `DateTime?` (nullable)
- **Optional**: Yes - existing locations have `null`, new locations can omit
- **Supports**: Past dates (historical filming) and future dates (scheduled productions)
- **Storage**: UTC timestamp in PostgreSQL

### API Endpoints Updated

#### 1. POST `/api/locations` - Create Location
**Request Body** (new field):
```json
{
  "name": "Central Park",
  "address": "...",
  "latitude": 40.785091,
  "longitude": -73.968285,
  "productionDate": "2025-12-31",  // NEW: Optional ISO date string (YYYY-MM-DD)
  "caption": "Beautiful park for outdoor scenes",
  "tags": ["outdoor", "park"]
}
```

**Response** (new field):
```json
{
  "data": {
    "id": 107,
    "name": "Central Park",
    "productionDate": "2025-12-31T00:00:00.000Z",  // NEW: ISO 8601 timestamp
    // ... other fields
  }
}
```

#### 2. PATCH `/api/locations/[id]` - Update Location
**Request Body** (new field):
```json
{
  "productionDate": "2025-12-31",  // NEW: Optional ISO date string
  "caption": "Updated caption",
  "tags": ["updated"]
}
```

**Null Handling**:
```json
{
  "productionDate": null  // Explicitly remove production date
}
```

**Response**:
```json
{
  "data": {
    "id": 107,
    "productionDate": "2025-12-31T00:00:00.000Z",  // NEW: Updated timestamp
    // ... other fields
  }
}
```

#### 3. GET `/api/locations` - List All Saved Locations
**Response** (existing endpoint, new field):
```json
{
  "data": [
    {
      "id": 107,
      "name": "Central Park",
      "productionDate": "2025-12-31T00:00:00.000Z",  // NEW: Nullable timestamp
      // ... other fields
    }
  ]
}
```

#### 4. GET `/api/locations/[id]` - Get Location Details
**Response** (existing endpoint, new field):
```json
{
  "data": {
    "id": 107,
    "name": "Central Park",
    "productionDate": "2025-12-31T00:00:00.000Z",  // NEW: Nullable timestamp
    // ... other fields
  }
}
```

---

## iOS Implementation Tasks

### 1. Update Swift Models

**File**: `fotolokashen/Models/Location.swift`

Add production date field to Location model:
```swift
struct Location: Codable, Identifiable {
    let id: Int
    let name: String
    let address: String?
    let latitude: Double
    let longitude: Double
    let productionDate: Date?  // NEW: Optional production date
    // ... existing fields
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case address
        case latitude
        case longitude
        case productionDate  // NEW: Add to coding keys
        // ... existing keys
    }
}
```

**Date Decoding Strategy**:
- Backend sends ISO 8601 timestamps (e.g., `2025-12-31T00:00:00.000Z`)
- Use `JSONDecoder.dateDecodingStrategy = .iso8601`
- Already configured in `LocationService.swift`

### 2. Update API Service

**File**: `fotolokashen/Services/LocationService.swift`

#### Create Location
```swift
func createLocation(
    name: String,
    address: String,
    latitude: Double,
    longitude: Double,
    productionDate: Date?,  // NEW: Optional production date
    caption: String?,
    tags: [String]?
) async throws -> Location {
    var parameters: [String: Any] = [
        "name": name,
        "address": address,
        "latitude": latitude,
        "longitude": longitude
    ]
    
    // NEW: Add production date if provided
    if let productionDate = productionDate {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]  // YYYY-MM-DD only
        parameters["productionDate"] = formatter.string(from: productionDate)
    }
    
    if let caption = caption {
        parameters["caption"] = caption
    }
    
    if let tags = tags {
        parameters["tags"] = tags
    }
    
    // ... make API request
}
```

#### Update Location
```swift
func updateLocation(
    id: Int,
    productionDate: Date?,  // NEW: Optional production date
    caption: String?,
    tags: [String]?
) async throws -> Location {
    var parameters: [String: Any] = [:]
    
    // NEW: Handle production date (including null)
    if let productionDate = productionDate {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        parameters["productionDate"] = formatter.string(from: productionDate)
    } else {
        parameters["productionDate"] = NSNull()  // Explicitly null to remove
    }
    
    if let caption = caption {
        parameters["caption"] = caption
    }
    
    if let tags = tags {
        parameters["tags"] = tags
    }
    
    // ... make API request
}
```

### 3. Update ViewModels

**File**: `fotolokashen/ViewModels/LocationViewModel.swift`

Add production date state:
```swift
@Published var productionDate: Date? = nil  // NEW: Optional production date

func saveLocation() async {
    do {
        let location = try await locationService.createLocation(
            name: locationName,
            address: locationAddress,
            latitude: latitude,
            longitude: longitude,
            productionDate: productionDate,  // NEW: Pass production date
            caption: caption,
            tags: tags
        )
        // ... handle success
    } catch {
        // ... handle error
    }
}

func updateLocation(id: Int) async {
    do {
        let location = try await locationService.updateLocation(
            id: id,
            productionDate: productionDate,  // NEW: Pass production date
            caption: caption,
            tags: tags
        )
        // ... handle success
    } catch {
        // ... handle error
    }
}
```

### 4. Update UI Views

#### A. Location Detail View
**File**: `fotolokashen/Views/Locations/LocationDetailView.swift`

Display production date:
```swift
VStack(alignment: .leading, spacing: 12) {
    // ... existing fields
    
    // NEW: Production Date Display
    if let productionDate = location.productionDate {
        HStack(spacing: 8) {
            Image(systemName: "calendar")
                .foregroundColor(.gray)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Production Date")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text(formatProductionDate(productionDate))
                    .font(.body)
            }
        }
    }
}

// Helper function
private func formatProductionDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .long  // "December 31, 2025"
    formatter.timeZone = TimeZone(secondsFromGMT: 0)  // Force UTC to match backend
    return formatter.string(from: date)
}
```

#### B. Edit Location View
**File**: `fotolokashen/Views/Locations/EditLocationView.swift`

Add date picker:
```swift
Form {
    // ... existing fields
    
    // NEW: Production Date Picker
    Section(header: Text("Production Details")) {
        DatePicker(
            "Production Date",
            selection: Binding(
                get: { viewModel.productionDate ?? Date() },
                set: { viewModel.productionDate = $0 }
            ),
            displayedComponents: [.date]
        )
        
        // Optional: Toggle for removing date
        Toggle("Has Production Date", isOn: Binding(
            get: { viewModel.productionDate != nil },
            set: { if !$0 { viewModel.productionDate = nil } }
        ))
    }
}
```

#### C. Create Location View
**File**: `fotolokashen/Views/Locations/CreateLocationView.swift`

Add date picker in form:
```swift
Form {
    // ... existing fields (name, address, etc.)
    
    // NEW: Production Date Picker
    Section(header: Text("Production Details")) {
        DatePicker(
            "Production Date (Optional)",
            selection: Binding(
                get: { viewModel.productionDate ?? Date() },
                set: { viewModel.productionDate = $0 }
            ),
            displayedComponents: [.date]
        )
        
        Toggle("Set Production Date", isOn: Binding(
            get: { viewModel.productionDate != nil },
            set: { if !$0 { viewModel.productionDate = nil } }
        ))
    }
}
```

---

## Date Handling Best Practices

### Backend → iOS
1. **Backend sends**: ISO 8601 timestamp (`2025-12-31T00:00:00.000Z`)
2. **iOS decodes**: Automatically to Swift `Date` using `.iso8601` strategy
3. **iOS displays**: Format with `DateFormatter` using UTC timezone

### iOS → Backend
1. **User selects**: Date via `DatePicker`
2. **iOS encodes**: Convert to ISO date string (YYYY-MM-DD only)
3. **Backend stores**: Convert to UTC timestamp in PostgreSQL

### Important Notes
- **Always use UTC**: Prevents timezone conversion issues
- **Date-only format**: Use `.withFullDate` for API requests (YYYY-MM-DD)
- **Nullable field**: Handle `nil` cases throughout the flow
- **Explicit null**: Use `NSNull()` to remove existing production dates

---

## Testing Checklist

### API Integration Tests
- [ ] Create location WITH production date
- [ ] Create location WITHOUT production date (should be `null`)
- [ ] Update location to ADD production date
- [ ] Update location to CHANGE production date
- [ ] Update location to REMOVE production date (set to `null`)
- [ ] Fetch location with production date (display correctly)
- [ ] Fetch location without production date (handle `nil`)

### UI Tests
- [ ] Date picker displays current date by default
- [ ] User can select past dates (historical filming)
- [ ] User can select future dates (scheduled productions)
- [ ] Toggle removes production date (sets to `nil`)
- [ ] Production date displays correctly in detail view
- [ ] Production date only shows when not `null`
- [ ] Date displays without timezone conversion (UTC-based)

### Edge Cases
- [ ] Create location with production date in 1900 (old historical)
- [ ] Create location with production date in 2100 (far future)
- [ ] Update location multiple times (date changes persist)
- [ ] Offline mode: Queue production date changes
- [ ] Network error: Handle gracefully, don't lose user input

---

## Migration Plan

### Phase 1: Model & Service Updates
1. Update `Location.swift` model
2. Update `LocationService.swift` API calls
3. Test API integration with Postman/curl

### Phase 2: ViewModel Updates
1. Add `@Published var productionDate: Date?`
2. Update create/update functions
3. Test with mock data

### Phase 3: UI Updates
1. Add date picker to Create Location view
2. Add date picker to Edit Location view
3. Add display to Location Detail view
4. Test user flows end-to-end

### Phase 4: Testing & Refinement
1. Test all edge cases
2. Test offline mode integration
3. Test timezone consistency
4. Final QA pass

---

## Example Usage

### Web App (Reference)
```typescript
// Edit Location Form (React Hook Form)
<div>
  <Label htmlFor="productionDate">Production Date</Label>
  <Input
    id="productionDate"
    type="date"
    {...register('productionDate')}
  />
</div>

// Detail Panel Display
{location.productionDate && (
  <div className="flex items-center gap-2">
    <Calendar className="h-4 w-4 text-gray-500" />
    <div>
      <p className="text-sm text-gray-600">Production Date</p>
      <p className="text-base">
        {new Date(location.productionDate).toLocaleDateString('en-US', {
          year: 'numeric',
          month: 'long',
          day: 'numeric',
          timeZone: 'UTC'
        })}
      </p>
    </div>
  </div>
)}
```

### iOS App (Target)
```swift
// Edit Location View
Section(header: Text("Production Details")) {
    DatePicker(
        "Production Date",
        selection: Binding(
            get: { viewModel.productionDate ?? Date() },
            set: { viewModel.productionDate = $0 }
        ),
        displayedComponents: [.date]
    )
}

// Detail View Display
if let productionDate = location.productionDate {
    HStack(spacing: 8) {
        Image(systemName: "calendar")
            .foregroundColor(.gray)
        
        VStack(alignment: .leading) {
            Text("Production Date")
                .font(.caption)
                .foregroundColor(.gray)
            
            Text(formatProductionDate(productionDate))
                .font(.body)
        }
    }
}
```

---

## Questions or Issues?

- **Backend errors**: Check `/docs/api/LOCATIONS_API.md` for troubleshooting
- **Date format issues**: Ensure using ISO8601DateFormatter with `.withFullDate`
- **Timezone problems**: Always use UTC timezone for date-only fields
- **API changes**: Coordinate with backend team before modifying endpoints

---

## Related Documentation
- Backend Implementation: `/docs/completed-features/PRODUCTION_DATE_FEATURE.md` (web app)
- API Specification: `/docs/api/LOCATIONS_API.md`
- iOS Development Stack: `/fotolokashen-ios/docs/IOS_DEVELOPMENT_STACK.md`
