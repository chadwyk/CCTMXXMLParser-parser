//
//  CCTMXXMLParser+parser.mm
//
//  Created by Wasabi on 12/6/10.
//  Copyright 2010 WasabiBit. All rights reserved.
//

#import "CCTMXXMLParser+parser.h"
@implementation CCTiledMapInfo (parser)


- (void) parseXMLFile:(NSString *)xmlFilename
{
	
    
     NSURL *url = [NSURL fileURLWithPath:[[CCFileUtils sharedFileUtils]  fullPathFromRelativePath:xmlFilename] ];

    NSXMLParser *parser = [[NSXMLParser alloc] initWithContentsOfURL:url];
	
	// we'll do the parsing
	[parser setDelegate:self];
	[parser setShouldProcessNamespaces:NO];
	[parser setShouldReportNamespacePrefixes:NO];
	[parser setShouldResolveExternalEntities:NO];
	[parser parse];
	
	NSAssert1( ! [parser parserError], @"Error parsing file: %@.", xmlFilename );
	}

// the XML parser calls here with all the elements
-(void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict
{	
	
	float scaleFactor = [[CCDirector sharedDirector] contentScaleFactor];
	
	if([elementName isEqualToString:@"map"]) {
		NSString *version = [attributeDict valueForKey:@"version"];
		if( ! [version isEqualToString:@"1.0"] )
			CCLOG(@"cocos2d: TMXFormat: Unsupported TMX version: %@", version);
		NSString *orientationStr = [attributeDict valueForKey:@"orientation"];
		if( [orientationStr isEqualToString:@"orthogonal"])
            [self setOrientation:CCTiledMapOrientationOrtho];
			//orientation_ = CCTiledMapOrientationOrtho;
		else if ( [orientationStr isEqualToString:@"isometric"])
            [self setOrientation:CCTiledMapOrientationIso];
		else if( [orientationStr isEqualToString:@"hexagonal"])
        [self setOrientation:CCTiledMapOrientationHex];
		else
			CCLOG(@"cocos2d: TMXFomat: Unsupported orientation: %i", self.orientation);
		
        [self setMapSize:CGSizeMake([[attributeDict valueForKey:@"width"] intValue], [[attributeDict valueForKey:@"height"] intValue])];
        
        [self setTileSize:CGSizeMake([[attributeDict valueForKey:@"tilewidth"] intValue],[[attributeDict valueForKey:@"tileheight"] intValue] )];
	//	tileSize_.width = [[attributeDict valueForKey:@"tilewidth"] intValue];
	//	tileSize_.height = [[attributeDict valueForKey:@"tileheight"] intValue];
		
		// The parent element is now "map"
        
		_parentElement = TMXPropertyMap;
	} else if([elementName isEqualToString:@"tileset"]) {
		
		// If this is an external tileset then start parsing that
		NSString *externalTilesetFilename = [attributeDict valueForKey:@"source"];
		if (externalTilesetFilename) {
			// Tileset file will be relative to the map file. So we need to convert it to an absolute path
			NSString *dir = [self.filename stringByDeletingLastPathComponent];	// Directory of map file
			externalTilesetFilename = [dir stringByAppendingPathComponent:externalTilesetFilename];	// Append path to tileset file
			
			[self parseXMLFile:externalTilesetFilename];
		} else {
			
			CCTiledMapTilesetInfo *tileset = [CCTiledMapTilesetInfo new];
			tileset.name = [attributeDict valueForKey:@"name"];
			tileset.firstGid = [[attributeDict valueForKey:@"firstgid"] intValue];
			tileset.spacing = [[attributeDict valueForKey:@"spacing"] intValue];
			tileset.margin = [[attributeDict valueForKey:@"margin"] intValue];
			CGSize s;
			s.width = [[attributeDict valueForKey:@"tilewidth"] intValue];
			s.height = [[attributeDict valueForKey:@"tileheight"] intValue];
			tileset.tileSize = s;
			
			[self.tilesets addObject:tileset];
		}
		
	}else if([elementName isEqualToString:@"tile"]){
		CCTiledMapTilesetInfo* info = [self.tilesets lastObject];
		NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithCapacity:3];
		_parentGID =  [info firstGid] + [[attributeDict valueForKey:@"id"] intValue];
		[self.tileProperties setObject:dict forKey:[NSNumber numberWithInt:_parentGID]];
		
		_parentElement = TMXPropertyTile;
		
	}else if([elementName isEqualToString:@"layer"]) {
		CCTiledMapLayerInfo *layer = [CCTiledMapLayerInfo new];
		layer.name = [attributeDict valueForKey:@"name"];
		
		CGSize s;
		s.width = [[attributeDict valueForKey:@"width"] intValue];
		s.height = [[attributeDict valueForKey:@"height"] intValue];
		layer.layerSize = s;
		
		layer.visible = ![[attributeDict valueForKey:@"visible"] isEqualToString:@"0"];
		
		if( [attributeDict valueForKey:@"opacity"] )
			layer.opacity = 255 * [[attributeDict valueForKey:@"opacity"] floatValue];
		else
			layer.opacity = 255;
		
		int x = [[attributeDict valueForKey:@"x"] intValue];
		int y = [[attributeDict valueForKey:@"y"] intValue];
		layer.offset = ccp(x,y);
		
		[self.layers addObject:layer];
		
		// The parent element is now "layer"
		_parentElement = TMXPropertyLayer;
		
	} else if([elementName isEqualToString:@"objectgroup"]) {
		
		CCTiledMapObjectGroup *objectGroup = [[CCTiledMapObjectGroup alloc] init];
		objectGroup.groupName = [attributeDict valueForKey:@"name"];
		CGPoint positionOffset;
		// WB changed:
		//OLD: positionOffset.x = [[attributeDict valueForKey:@"x"] intValue] * tileSize_.width;
		//OLD: positionOffset.y = [[attributeDict valueForKey:@"y"] intValue] * tileSize_.height;
		positionOffset.x = [[attributeDict valueForKey:@"x"] intValue] * self.tileSize.width / scaleFactor;
		positionOffset.y = [[attributeDict valueForKey:@"y"] intValue] * self.tileSize.height / scaleFactor;
		objectGroup.positionOffset = positionOffset;
		
		[self.objectGroups addObject:objectGroup];
		
		// The parent element is now "objectgroup"
		_parentElement = TMXPropertyObjectGroup;
		
	} else if([elementName isEqualToString:@"image"]) {
		
		CCTiledMapTilesetInfo *tileset = [self.tilesets lastObject];
		
		// build full path
		NSString *imagename = [attributeDict valueForKey:@"source"];		
		NSString *path = [self.filename stringByDeletingLastPathComponent];
		tileset.sourceImage = [path stringByAppendingPathComponent:imagename];
		
	} else if([elementName isEqualToString:@"data"]) {
		NSString *encoding = [attributeDict valueForKey:@"encoding"];
		NSString *compression = [attributeDict valueForKey:@"compression"];
		
		if( [encoding isEqualToString:@"base64"] ) {
			_layerAttribs |= TMXLayerAttribBase64;
			_storingCharacters = YES;
			
			if( [compression isEqualToString:@"gzip"] )
				_layerAttribs |= TMXLayerAttribGzip;
            
            else if( [compression isEqualToString:@"zlib"] )
                _layerAttribs |= TMXLayerAttribZlib;
			
			NSAssert( !compression || [compression isEqualToString:@"gzip"] || [compression isEqualToString:@"zlib"], @"TMX: unsupported compression method" );
		}
		
		NSAssert( _layerAttribs != TMXLayerAttribNone, @"TMX tile map: Only base64 and/or gzip maps are supported" );
		
	} else if([elementName isEqualToString:@"object"]) {
		
		CCTiledMapObjectGroup *objectGroup = [self.objectGroups lastObject];
		
		// The value for "type" was blank or not a valid class name
		// Create an instance of TMXObjectInfo to store the object and its properties
		NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithCapacity:5];
		
		// Set the name of the object to the value for "name"
		[dict setValue:[attributeDict valueForKey:@"name"] forKey:@"name"];
		
		// Assign all the attributes as key/name pairs in the properties dictionary
		[dict setValue:[attributeDict valueForKey:@"type"] forKey:@"type"];
		
		
		// WB Changed:
		//OLD: int x = [[attributeDict valueForKey:@"x"] intValue] + objectGroup.positionOffset.x;
		int x = [[attributeDict valueForKey:@"x"] intValue]/scaleFactor + objectGroup.positionOffset.x;
		[dict setValue:[NSNumber numberWithInt:x] forKey:@"x"];
		//OLD: int y = [[attributeDict valueForKey:@"y"] intValue] + objectGroup.positionOffset.y;		
		int y = [[attributeDict valueForKey:@"y"] intValue]/scaleFactor + objectGroup.positionOffset.y;
		
		//DebugLog(@"ZZZ 2+++++ attributeDict: x1=%d, new_x1=%d", [[attributeDict valueForKey:@"x"] intValue], x);
		//DebugLog(@"ZZZ 2+++++ attributeDict: y1=%d, new_y1=%d", [[attributeDict valueForKey:@"y"] intValue], y);
		
		// Correct y position. (Tiled uses Flipped, cocos2d uses Standard)
		//OLD: y = (mapSize_.height * tileSize_.height) - y - [[attributeDict valueForKey:@"height"] intValue]/scaleFactor;
		y = (self.mapSize.height * self.tileSize.height / scaleFactor) - y - [[attributeDict valueForKey:@"height"] intValue]/scaleFactor;
		[dict setValue:[NSNumber numberWithInt:y] forKey:@"y"];
		
		// WB changed:
		//OLD:[dict setValue:[attributeDict valueForKey:@"width"] forKey:@"width"];
		//OLD:[dict setValue:[attributeDict valueForKey:@"height"] forKey:@"height"];
		int width = [[attributeDict valueForKey:@"width"] intValue]/scaleFactor;
		int height = [[attributeDict valueForKey:@"height"] intValue]/scaleFactor;
		[dict setValue:[NSNumber numberWithInt:width] forKey:@"width"];
		[dict setValue:[NSNumber numberWithInt:height] forKey:@"height"];
		
		// Add the object to the objectGroup
		[[objectGroup objects] addObject:dict];
		
		// The parent element is now "object"
		_parentElement = TMXPropertyObject;
		
	} else if([elementName isEqualToString:@"property"]) {
		
		if ( _parentElement == TMXPropertyNone ) {
			
			CCLOG( @"TMX tile map: Parent element is unsupported. Cannot add property named '%@' with value '%@'",
				  [attributeDict valueForKey:@"name"], [attributeDict valueForKey:@"value"] );
			
		} else if ( _parentElement == TMXPropertyMap ) {
			
			// The parent element is the map
			[self.properties setValue:[attributeDict valueForKey:@"value"] forKey:[attributeDict valueForKey:@"name"]];
			
		} else if ( _parentElement == TMXPropertyLayer ) {
			
			// The parent element is the last layer
			CCTiledMapLayerInfo *layer = [self.layers lastObject];
			// Add the property to the layer
			[[layer properties] setValue:[attributeDict valueForKey:@"value"] forKey:[attributeDict valueForKey:@"name"]];
			
		} else if ( _parentElement == TMXPropertyObjectGroup ) {
			
			// The parent element is the last object group
			CCTiledMapObjectGroup *objectGroup = [self.objectGroups lastObject];
			[[objectGroup properties] setValue:[attributeDict valueForKey:@"value"] forKey:[attributeDict valueForKey:@"name"]];
			
		} else if ( _parentElement == TMXPropertyObject ) {
			
			// The parent element is the last object
			CCTiledMapObjectGroup *objectGroup = [self.objectGroups lastObject];
			NSMutableDictionary *dict = [[objectGroup objects] lastObject];
			
			NSString *propertyName = [attributeDict valueForKey:@"name"];
			NSString *propertyValue = [attributeDict valueForKey:@"value"];
			
			[dict setValue:propertyValue forKey:propertyName];
		} else if ( _parentElement == TMXPropertyTile ) {
			
			NSMutableDictionary* dict = [self.tileProperties objectForKey:[NSNumber numberWithInt:_parentGID]];
			NSString *propertyName = [attributeDict valueForKey:@"name"];
			NSString *propertyValue = [attributeDict valueForKey:@"value"];
			[dict setObject:propertyValue forKey:propertyName];
			
		}
	}
}

@end
