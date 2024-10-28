"""
Applet: Trash Day
Summary: Shows garbage pickup days
Description: Shows municipal garbage pickup for NYC, UK and DC.
Author: RobRoseKnows
"""

load("schema.star", "schema")
load("encoding/json.star", "json")
load("time.star", "time")
load("render.star", "render")
load("http.star", "http")
load("humanize.star", "humanize")
load("encoding/base64.star", "base64")

DEFAULT_LOCATION = """{
    "lat": 0,
    "lng": 0,
    "description": "Default",
    "locality": "Default",
    "place_id": "",
    "timezone": "America/New_York"
}"""

ICONS = {
    "RECYCLE": base64.decode("""

"""),
    "TRASH": base64.decode("""

"""),
    "BULK": base64.decode("""

"""),
    "COMPOST": base64.decode("""

"""),
    "CANCEL": base64.decode("""

"""),
}

WEEK = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
PIXELS_PER_DAY = 8

def get_ttl(location):
    """Get the time to live (in seconds) for the display and the data that goes into it.

    Args:
        location: The location context containing the timezone.
    Returns:
        the time to live in seconds
    """
    tz = location.get("timezone", "America/New_York")
    now = time.now().in_location(tz)
    if humanize.day_of_week(now) == 0 or humanize.day_of_week(now) == 1:
        # cache for an hour if it's sunday or monday, as we may be updating soon
        return 60 * 60

    # cache for a day otherwise, these schedules don't change much day to day.
    return 60 * 60 * 24

def main(config):
    location = json.decode(config.str("location", DEFAULT_LOCATION))
    return render.Root(child = calendar_for_locality(location), max_age = get_ttl(location))

def get_schema():
    return schema.Schema(
        version = "1",
        fields = [
            schema.Location(
                id = "location",
                name = "Location",
                desc = "Location for which to show trash pickup info.",
                icon = "locationDot",
            ),
        ],
    )

def calendar_for_locality(location):
    """Returns the rendered result for a locality based on the location.

    Args:
        location: dictionary containing the location data, MUST have locality and a description containing the full address.
    Returns:
        The resulting trash pickup calendar for this week.
    """
    locality = location.get("locality", "Default")
    if locality.startswith("Brooklyn"):
        return render_days(location, get_data_nyc(location))
    elif locality.startswith("New York City"):
        return render_days(location, get_data_nyc(location))
    elif locality.startswith("Manhattan"):
        return render_days(location, get_data_nyc(location))
    elif locality.startswith("Queens"):
        return render_days(location, get_data_nyc(location))
    elif locality.startswith("Staten Island"):
        return render_days(location, get_data_nyc(location))
    elif locality.startswith("Bronx"):
        return render_days(location, get_data_nyc(location))
    elif locality.endswith("UK"):
        return render_days(location, get_data_uk(location))
    elif locality == "Washington, DC":
        return render_days(location, get_data_dc(location))
    else:
        return render_default()

def get_data_dc(location):
    """Returns the data for the calendar for DC locations.

    Args:
        location: A dictionary cotnaining the location config. Must contain a description cotnaining the address and the timezone.
    Returns:
        A dictionary containing list of days, and the pickups scheduled on those days.
    """
    pass

def get_data_uk(location):
    """Returns the data for the calendar for UK locations.

    Args:
        location: A dictionary cotnaining the location config. Must contain a description cotnaining the address and the timezone.
    Returns:
        A dictionary containing list of days, and the pickups scheduled on those days.
    """
    pass

def get_data_nyc(location):
    """Returns the data for the calendar for NYC locations.

    Args:
        location: A dictionary cotnaining the location config. Must contain a description cotnaining the address and the timezone.
    Returns:
        A dictionary containing list of days, and the pickups scheduled on those days.
    """
    DEFAULT_DAYS = {
        "Mon": [],
        "Tue": [],
        "Wed": [],
        "Thu": [],
        "Fri": [],
        "Sat": [],
        "Sun": [],
    }
    BASE_URL = "https://dsnypublic.nyc.gov/dsny/api/geocoder/DSNYCollection?address="
    DEFAULT_ADDRESS = "20 W 34th St., New York, NY 10118, USA"
    street_address = humanize.url_encode(location.get("description", DEFAULT_ADDRESS))
    url = BASE_URL + street_address
    res = http.get(url, ttl_seconds = get_ttl(location))
    if res.status_code != 200:
        fail("GET %s failed with status %d: %s", url, res.status_code, res.body())
    data = res.json()
    bulk_days = [day[:3] for day in data.get("BulkPickupCollectionSchedule", "").split(",")]
    trash_days = [day[:3] for day in data.get("RegularCollectionSchedule", "").split(",")]
    recycle_days = [day[:3] for day in data.get("RecyclingCollectionSchedule", "").split(",")]
    compost_days = [day[:3] for day in data.get("OrganicsCollectionSchedule", "").split(",")]
    days = dict(DEFAULT_DAYS)
    for day in bulk_days:
        days[day].append("BULK")
    for day in trash_days:
        days[day].append("TRASH")
    for day in recycle_days:
        days[day].append("RECYCLE")
    for day in compost_days:
        days[day].append("COMPOST")
    return days

def render_default():
    """Renders a default display for unsupported regions.

    Returns:
        A WrappedText message that tells the user something is wrong.
    """
    text = "Unsupported locality! Try a different location!"
    return render.WrappedText(text, align = "center")

def render_days(location, data):
    """Render columns for the days of the current week.

    Args:
        location: The location config
        data: The total week's pickup schedule in a dictionary keyed on day, with ICONS.keys as values.
    Returns:
        A Widget that makes up the calendar.
    """
    tz = location.get("timezone", "America/New_York")
    now = time.now().in_location(tz)
    cols = []
    for day in WEEK:
        cols.append(render.Column(
            children = render_day(day, data[day], now),
            main_align = "start",
            cross_align = "center",
            expanded = True,
        ))
    return render.Row(children = cols, expanded = True, main_align = "space_around")

def render_day(day, data, now):
    """Render the each day's column.

    Args:
        day: The day we want to render. Must be in the WEEK list.
        data: The current day's pickup schedule with ICONS.keys as values.
        now: The current datetime with timezone.
    Returns:
        A list of widgets that make up a column.
    """
    widgets = []

    # Render the day letter.
    widgets.append(render.Text(day[0], font = "CG-pixel-4x5-mono"))

    # Render the line underneath the day letter, blue if it's today, red if it's earlier in the week and green if it's later.
    curr_day = now.format("Mon")
    if curr_day == day:
        widgets.append(render.Box(width = PIXELS_PER_DAY, height = 1, color = "#00a"))
    elif WEEK.index(curr_day) > WEEK.index(day):
        widgets.append(render.Box(width = PIXELS_PER_DAY, height = 1, color = "#a00"))
    else:
        widgets.append(render.Box(width = PIXELS_PER_DAY, height = 1, color = "#0a0"))

    for pickup in data[:3]:
        widgets.append(render_pickup(pickup))

    return widgets

def render_pickup(type):
    """Renders the icons for pickups of a specific type.

    Args:
        type: One of the types of pickups (recycle, trash, bulk, compost or cancel).
    Returns:
        A widget representing that pickup type.
    """
    if type == "RECYCLE":
        return render.Box(width = 8, height = 8, color = "#00a")
    elif type == "TRASH":
        return render.Box(width = 8, height = 8, color = "#aa0")
    elif type == "BULK":
        return render.Box(width = 8, height = 8, color = "#0aa")
    elif type == "COMPOST":
        return render.Box(width = 8, height = 8, color = "#0a0")
    elif type == "CANCEL":
        return render.Box(width = 8, height = 8, color = "#a00")
    else:
        fail("Unexpected type to render: %s", type)
