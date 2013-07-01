//
//  ViewController.m
//  Photo Map
//
//  Created by Alex Shevlyakov on 27.06.13.
//  Copyright (c) 2013 Alex Shevlyakov. All rights reserved.
//

#import "ViewController.h"
#import "PhotoAnnotation.h"
#import "PhotosViewController.h"

@implementation ViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        _assetsLoaded = NO;
        assetsLibrary = [[ALAssetsLibrary alloc] init];    
    }
    return self;
}

#pragma mark - UIViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
//    MKCoordinateRegion region = { { 36.102376, -119.091797 }, { 32.451446, 28.125000 } };
//    self.mapView.region = region;
    
    _allAnnotationsMapView = [[MKMapView alloc] initWithFrame:CGRectZero];
    [self loadAssets];
}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void)setAssetsLoaded:(BOOL)assetsLoaded
{
    _assetsLoaded = assetsLoaded;
    if (_assetsLoaded) {
        [self populateWorldWithAllPhotoAnnotations];
    }
}

- (void)loadAssets
{
    self.assetsLoaded = NO;
    if (!assets) {
        assets = [[NSMutableArray alloc] init];
    } else {
        [assets removeAllObjects];
    }
    
    void (^assetEnumerator)(ALAsset *, NSUInteger, BOOL *) = ^(ALAsset *result, NSUInteger index, BOOL *stop) {
        if(result != nil) {
            [assets addObject:result];
        }
    };
    
    ALAssetsLibraryGroupsEnumerationResultsBlock listGroupBlock = ^(ALAssetsGroup *group, BOOL *stop) {
        if (group != nil) {
            [group enumerateAssetsUsingBlock:assetEnumerator];
        } else {
            self.assetsLoaded = YES;
        }
    };
    
    ALAssetsLibraryAccessFailureBlock failureBlock = ^(NSError *error) {
        NSString *errorMessage = nil;
        switch ([error code]) {
            case ALAssetsLibraryAccessUserDeniedError:
            case ALAssetsLibraryAccessGloballyDeniedError:
                errorMessage = @"The user has declined access to it.";
                break;
            default:
                errorMessage = @"Reason unknown.";
                break;
        }
        NSLog(@"Assets Library access failure: %@", errorMessage);
    };
    
    NSUInteger groupTypes = ALAssetsGroupSavedPhotos | ALAssetsGroupAlbum | ALAssetsGroupEvent;
    [assetsLibrary enumerateGroupsWithTypes:groupTypes usingBlock:listGroupBlock failureBlock:failureBlock];
}

- (NSArray *)photosAnnotations
{    
    NSMutableArray *photos;
    NSString *archivePath = @"device_photos.archive";
    photos = [NSKeyedUnarchiver unarchiveObjectWithFile:archivePath];
    if (photos) {
        return photos;
    } else {
        photos = [NSMutableArray array];
    }
    
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [queue setMaxConcurrentOperationCount:8];
    
    for (ALAsset *asset in assets) {
        [queue addOperationWithBlock:^{
        
            ALAssetRepresentation *representation = [asset defaultRepresentation];
            NSDictionary *metadata = [representation metadata];
            NSDictionary *gpsDict = [metadata objectForKey:@"{GPS}"];
            
            if (gpsDict == nil)
                return;
            
            NSNumber *latitudeNumber = [gpsDict objectForKey:@"Latitude"];
            NSString *latitudeRef = [gpsDict objectForKey:@"LatitudeRef"];
            
            NSNumber *longitudeNumber = [gpsDict objectForKey:@"Longitude"];
            NSString *longitudeRef = [gpsDict objectForKey:@"LongitudeRef"];
            
            if (latitudeNumber == nil || longitudeNumber == nil)
                return;
            
            CLLocationCoordinate2D coord;
            coord.latitude  = latitudeNumber.doubleValue;
			coord.longitude = longitudeNumber.doubleValue;
            
            if ([latitudeRef  isEqualToString:@"S"]) coord.latitude  *= -1;
            if ([longitudeRef isEqualToString:@"W"]) coord.longitude *= -1;

            NSString *filename = [representation filename];
            PhotoAnnotation *photo = [[PhotoAnnotation alloc] initWithImagePath:representation.url.path title:filename coordinate:coord];
            
            NSLog(@"Asset: %@", asset.description);
            
            @synchronized(photos) {
                [photos addObject:photo];
            }
        }];
    }
    [queue waitUntilAllOperationsAreFinished];
    
    [NSKeyedArchiver archiveRootObject:photos toFile:archivePath];
    
    return photos;
}

- (void)populateWorldWithAllPhotoAnnotations
{    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    	self.photos = [self photosAnnotations];
        
        dispatch_async(dispatch_get_main_queue(), ^{
        	[_allAnnotationsMapView addAnnotations:self.photos];
            [self updateVisibleAnnotations];
        });
    });
}

- (id<MKAnnotation>)annotationInGrid:(MKMapRect)gridMapRect usingAnnotations:(NSSet *)annotations
{
    // First, see if one of the annotations we were already showing is in this MapRect
    NSSet *visibleAnnotationsInBucket = [self.mapView annotationsInMapRect:gridMapRect];
    NSSet *annotationsForGridSet = [annotations objectsPassingTest:^BOOL(id obj, BOOL *stop) {
    	BOOL returnValue = ([visibleAnnotationsInBucket containsObject:obj]);
        if (returnValue)
            *stop = YES;
        return returnValue;
    }];
    
    if (annotationsForGridSet.count != 0) {
        return [annotationsForGridSet anyObject];
    }
    
    // Otherwise, sort the annotations based on their distance from the center of the grid square,
    // then choose the one closest to the center to show
    MKMapPoint centerMapPoint = MKMapPointMake(MKMapRectGetMidX(gridMapRect), MKMapRectGetMidY(gridMapRect));
    NSArray *sortedAnnotations = [[annotations allObjects] sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        MKMapPoint mapPoint1 = MKMapPointForCoordinate( ((id<MKAnnotation>)obj1).coordinate );
        MKMapPoint mapPoint2 = MKMapPointForCoordinate( ((id<MKAnnotation>)obj2).coordinate );
        
        CLLocationDistance distance1 = MKMetersBetweenMapPoints(mapPoint1, centerMapPoint);
        CLLocationDistance distance2 = MKMetersBetweenMapPoints(mapPoint2, centerMapPoint);
        
        if (distance1 < distance2) {
            return NSOrderedAscending;
        } else if (distance1 > distance2) {
            return NSOrderedDescending;
        }
        
        return NSOrderedSame;
    }];
    
    return [sortedAnnotations objectAtIndex:0];
}


- (void)updateVisibleAnnotations {
    // Fix performance and visual clutter by calling update when we change map regions
    // This value to controls the number of off screen annotations are displayed.
    // A bigger number means more annotations, less chance of seeing annotation views pop in but decreased performance.
    // A smaller number means fewer annotations, more chance of seeing annotation views pop in but better performance.
    static float marginFactor = 2.0;
    
    // Adjust this roughly based on the dimensions of your annotations views.
    // Bigger numbers more aggressively coalesce annotations (fewer annotations displayed but better performance).
    // Numbers too small result in overlapping annotations views and too many annotations on screen.
    static float bucketSize = 60.0;
    
    // Find all the annotations in the visible area + a wide margin to avoid popping annotation views in and out while panning the map.
    MKMapRect visibleMapRect = [self.mapView visibleMapRect];
    MKMapRect adjustedVisibleMapRect = MKMapRectInset(visibleMapRect, -marginFactor * visibleMapRect.size.width, -marginFactor * visibleMapRect.size.height);
    
    // Determine how wide each bucket will be, as a MapRect square
    CLLocationCoordinate2D leftCoordinate  = [self.mapView convertPoint:CGPointZero toCoordinateFromView:self.view];
    CLLocationCoordinate2D rightCoordinate = [self.mapView convertPoint:CGPointMake(bucketSize, 0) toCoordinateFromView:self.view];
    double gridSize = MKMapPointForCoordinate(rightCoordinate).x - MKMapPointForCoordinate(leftCoordinate).x;
    MKMapRect gridMapRect = MKMapRectMake(0, 0, gridSize, gridSize);
    
    // Condense annotations, with a padding of two squares, around the visibleMapRect
    double startX = floor(MKMapRectGetMinX(adjustedVisibleMapRect) / gridSize) * gridSize;
    double startY = floor(MKMapRectGetMinY(adjustedVisibleMapRect) / gridSize) * gridSize;
    double endX   = floor(MKMapRectGetMaxX(adjustedVisibleMapRect) / gridSize) * gridSize;
    double endY   = floor(MKMapRectGetMaxY(adjustedVisibleMapRect) / gridSize) * gridSize;
    
    // For each square in our grid, pick one annotation to show
    gridMapRect.origin.y = startY;
    while (MKMapRectGetMinY(gridMapRect) <= endY) {
        gridMapRect.origin.x = startX;
        
        while (MKMapRectGetMinX(gridMapRect) <= endX) {
            NSSet *allAnnotationsInBucket = [_allAnnotationsMapView annotationsInMapRect:gridMapRect];
            NSSet *visibleAnnotationsInBucket = [self.mapView annotationsInMapRect:gridMapRect];
            
            // We only care about PhotoAnnotations
            NSMutableSet *filteredAnnotationsInBucket = [[allAnnotationsInBucket objectsPassingTest:^BOOL(id obj, BOOL *stop) {
                return ([obj isKindOfClass:[PhotoAnnotation class]]);
            }] mutableCopy];
            
            if (filteredAnnotationsInBucket.count > 0) {
                PhotoAnnotation *annotationForGrid = (PhotoAnnotation *)[self annotationInGrid:gridMapRect usingAnnotations:filteredAnnotationsInBucket];
                
                [filteredAnnotationsInBucket removeObject:annotationForGrid];
                
                // Give the annotationForGrid a reference to all the annotations it will represent
                annotationForGrid.containedAnnotations = [filteredAnnotationsInBucket allObjects];
                
                [self.mapView addAnnotation:annotationForGrid];
                
                
                for (PhotoAnnotation *annotation in filteredAnnotationsInBucket) {
                    // Give all the other annotations a reference to the one which is representing them
                    annotation.clusterAnnotation = annotationForGrid;
                    annotation.containedAnnotations = nil;
                    
                    // Remove annotations which we've decided to cluster
                    if ([visibleAnnotationsInBucket containsObject:annotation]) {
                        //[self.mapView removeAnnotation:annotation];
                        
                        CLLocationCoordinate2D actualCoordinate = annotation.coordinate;
                        [UIView animateWithDuration:0.3 animations:^{
                            annotation.coordinate = annotation.clusterAnnotation.coordinate;
                        } completion:^(BOOL finished) {
                            annotation.coordinate = actualCoordinate;
                            [self.mapView removeAnnotation:annotation];
                        }];
                    }
                }
            }
            
            gridMapRect.origin.x += gridSize;
        }
        gridMapRect.origin.y += gridSize;
    }
}


#pragma mark - MKMapViewDelegate

- (void)mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated
{
    [self updateVisibleAnnotations];
}

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation
{
    if (mapView != self.mapView)
        return nil;
    
    if ([annotation isKindOfClass:[PhotoAnnotation class]]) {
    	MKPinAnnotationView *annotationView = (MKPinAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:@"Photo"];
        if (annotationView == nil)
            annotationView = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:@"Photo"];
        
        annotationView.canShowCallout = YES;
        
        UIButton *disclosureButton = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];
        annotationView.rightCalloutAccessoryView = disclosureButton;
        
        return annotationView;
    }
    return nil;
}

- (void)mapView:(MKMapView *)mapView annotationView:(MKAnnotationView *)view calloutAccessoryControlTapped:(UIControl *)control
{
    if (![view.annotation isKindOfClass:[PhotoAnnotation class]])
        return;
    
    PhotoAnnotation *annotation = (PhotoAnnotation *)view.annotation;
    
    NSMutableArray *photosToShow = [NSMutableArray arrayWithObject:annotation];
    [photosToShow addObjectsFromArray:annotation.containedAnnotations];
    
    PhotosViewController *viewController = [[PhotosViewController alloc] init];
    viewController.photos = photosToShow;
    [self.navigationController pushViewController:viewController animated:YES];
}

- (void)mapView:(MKMapView *)mapView didAddAnnotationViews:(NSArray *)views
{
    for (MKAnnotationView *annotationView in views) {
        if (![annotationView.annotation isKindOfClass:[PhotoAnnotation class]])
            continue;
        
        PhotoAnnotation *annotation = (PhotoAnnotation *)annotationView.annotation;
        
        if (annotation.clusterAnnotation != nil) {
            // Animate the annotation from it's old container's coordinate, to its actual coordinate
            CLLocationCoordinate2D actualCoordinate = annotation.coordinate;
            CLLocationCoordinate2D containerCoordinate = annotation.clusterAnnotation.coordinate;
            
            annotation.clusterAnnotation = nil;
            annotation.coordinate = containerCoordinate;
            
            [UIView animateWithDuration:0.3 animations:^{
            	annotation.coordinate = actualCoordinate;
            }];
        }
    }
}

@end
