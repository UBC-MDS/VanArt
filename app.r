library(shiny)
library(ggplot2)
library(leaflet)
library(tidyverse)
library(treemapify)
library(thematic)
library(shinythemes)

# read data
data <- read_csv2("data/public-art.csv")

# separate longitude and latitude and convert to numeric for plot
data <- separate(data,
                 col = "geo_point_2d",
                 into = c("latitude", "longitude"), sep = ", ") |> 
  mutate(latitude = as.numeric(latitude),
         longitude = as.numeric(longitude),
         Neighborhood = coalesce("Neighborhood", "Geo Local Area")) |> 
  filter(!if_any(Neighbourhood, is.na))
# impute missing values in neighborhood using Geo Local Area

ui <- fluidPage(
  
  # theme 
  theme = shinytheme("lumen"),
  
  # title
  navbarPage(title="VanArt: Discover Public Art in Vancouver! 🎨🌆"),
  br(),
  
)

server <- function(input, output, session){
  # applies theme selected for the app to ggplot
  thematic::thematic_shiny() 
  
  # Create reactive data 
  reactive_data <- 
    reactive({
      # set default view as all data
      filtered_data <- data
      
      # filter based on input years
      if (!is.null(input$bins)) {
        filtered_data <- 
          filtered_data |> 
          filter(
            YearOfInstallation >= input$bins[1] &
              YearOfInstallation <= input$bins[2])
      }
      
      # # filter based on artist
      # if (!is.null(input$artist)) {
      #   filtered_data <- 
      #     filtered_data |> 
      #     filter(Artist %in% input$artist)
      # }
      
      # filter based on art type
      if (!is.null(input$type)) {
        filtered_data <- 
          filtered_data |> 
          filter(Type %in% input$type)
      }
      
      # filter based on neighbourhood
      if (!is.null(input$neighbourhood)) {
        filtered_data <- 
          filtered_data |> 
          filter(Neighbourhood %in% input$neighbourhood)
      }
      
      filtered_data  # original (if no inputs) or filtered data is returned
    })
  
  # Create main geographical map
  output$mainMap <- renderLeaflet({
    leaflet(reactive_data(),
            options = leafletOptions(
              attributionControl=FALSE)) |>
      addTiles() |>  
      addCircleMarkers(
        lat = ~latitude,
        lng = ~longitude,
        radius = 5,
        color = "darkblue",
        clusterOptions = markerClusterOptions(),
        popup = ~paste(
          "<b>Title of work</b>: ", `Title of Work`, "<br>",
          "<b>Type of art</b>: ", Type, "<br>",
          "<b>Description</b>: ", DescriptionOfwork, "<br> <br>",
          "<b>Address</b>: ", SiteAddress, "<br>",
          "<b>Year installed</b>: ", YearOfInstallation, "<br>",
          # "<b>Photo URL</b>: ", "<a href='",
          # PhotoURL,
          # "' target='_blank'>Click here to view image.</a>", "<br> <br>"
          "<b>Photo:</b><br><img src='",
          PhotoURL,
          "' style='max-width:200px; max-height:200px;'><br>"
        ),
        popupOptions = popupOptions(
          closeButton = TRUE,
          className = "popup-scroll"
        )
      )
  })
  
  
  # Create density plot 
  output$densityPlot <- renderPlot({
    reactive_data() |>
      ggplot(aes(YearOfInstallation)) +
      geom_density(fill = "grey", alpha = 0.8) +
      labs(
        x = "Year of installation",
        y = "Density"
      )
  })   
  # Create barplot 
  
  output$barPlot <- renderPlot({
    grouped_data <- 
      reactive_data() |> 
      group_by(Neighbourhood) |> 
      summarise(num_art = n())
    
    grouped_data |> 
      ggplot(aes(x = num_art, y = reorder(Neighbourhood, -num_art))) +
      geom_bar(stat = "identity") + 
      labs(
        x = "Number of art pieces",
        y = "Neighbourhood"
      )
  })
  # Create tree chart
  
  output$treePlot <- renderPlot({
    reactive_data() |> 
      group_by(Type) |> 
      summarise(type_num = n()) |>
      ggplot(aes(area = type_num, 
                 fill = Type, 
                 label = type_num)) +
      geom_treemap() +
      geom_treemap_text(colour = "white",
                        place = "centre",
                        size = 15) +
      scale_fill_viridis_d() +
      labs(title = "Number of Art Pieces by Type")
  })
  
}

shinyApp(ui, server)