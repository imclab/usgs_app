library(shiny)
library(plyr)
library(taxize)
library(ggplot2)
library(doMC)
library(ape)
library(ggphylo)
library(rgbif)
library(RSQLite)

## Set up server output
shinyServer(function(input, output) {
  #   load("speciesdata.rda")
  
  datasetInput <- reactive({
#   	conn <- taxize:::sqlite_init(path="~/ShinyApps/usgs/itis2.sqlite")
  	conn <- taxize:::sqlite_init(path="~/github/ropensci/taxize_/inst/sql/itis2.sqlite")
  	
    species <- input$spec
    species2 <- strsplit(species, ",")[[1]]
    
    # get locally choice
    if(input$locally=="local sqlite3") {locally_choice <- TRUE} else {locally_choice <- FALSE}
    
    # Get ITIS data
    tsns <- get_tsn(searchterm=species2, searchtype="sciname", locally=locally_choice, cn=conn)
    
    ## Get hierarchy up from species
    if (input$getup) {
    	if(!locally_choice){
    		registerDoMC(cores=4)
    		itisdata_getup <- ldply(tsns, gethierarchyupfromtsn, .parallel=TRUE)	
    	} else
    	{
    		itisdata_getup <- ldply(tsns, gethierarchyupfromtsn, locally=locally_choice)	
    	}
    } else {itisdata_getup <- NULL}
    
#     ## Get downstream from taxon
#     if (is.character(input$getdown)) {
#     	registerDoMC(cores=4)
#     	itisdata_getdown <- ldply(tsns, itis_downstream, downto = input$getdown, .parallel=TRUE)[,-1]	
#     } else {itisdata_getdown <- NULL}
#     
#     ## Get synonyms
#     if (is.character(input$getdown)) {
#     	registerDoMC(cores=4)
#     	itisdata_syns <- ldply(tsns, getsynonymnamesfromtsn, .parallel=TRUE)[,-1]
#     } else {itisdata_syns <- NULL}
#     
#     ## put ITIS data into a list
#     itisdata_list <- compact(list(itisdata_getup,itisdata_getdown,itisdata_syns))
#     
#     
    
    # Invasivesnes status
    dat <- gisd_isinvasive(x=species2, simplify=TRUE)
    
    
    
    # Make phylogeny
    registerDoMC(cores=4)
    phylog <- phylomatic_tree(taxa=species2, get = 'POST', informat='newick', method = "phylomatic",
                    storedtree = "R20120829", taxaformat = "slashpath", outformat = "newick", clean = "true", parallel=TRUE)
    phylog$tip.label <- capwords(phylog$tip.label)
    
    for(i in seq_along(phylog$tip.label)){
      phylog <- tree.set.tag(phylog, tree.find(phylog, phylog$tip.label[i]), 'circle', dat[dat$species %in% gsub("_"," ",phylog$tip.label[i]),"status"])
    }
    phylog2 <- ggphylo(phylog, label.size=5, label.color.by='circle', label.color.scale=scale_colour_discrete(h=c(90, 10))) + theme_phylo_blank()
    
    
    
    # Make map
    registerDoMC(cores=4)
    out <- llply(species2, function(x) occurrencelist(x, coordinatestatus = TRUE, maxresults = 100), .parallel=TRUE)
    map <- gbifmap(out)
    
    
    # PUt output in a list
#     list(itisdata_list, dat, phylog2, map)
    list(itisdata_getup, dat, phylog2, map)
  })
  
  
  
  output$itis_data <- renderTable({
  	datasetInput()[[1]]
  })
  
  output$invasiveness <- renderTable({
  	datasetInput()[[2]]
  })
  
  output$phylogeny <- renderPlot({
    print(datasetInput()[[3]])
  })
  
  output$map <- renderPlot({
    print(datasetInput()[[4]])
  })
})