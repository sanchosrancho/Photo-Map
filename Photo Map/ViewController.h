//
//  ViewController.h
//  Photo Map
//
//  Created by Alex Shevlyakov on 27.06.13.
//  Copyright (c) 2013 Alex Shevlyakov. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>
#import <ImageIO/ImageIO.h>
#import <AssetsLibrary/AssetsLibrary.h>

@interface ViewController : UIViewController <MKMapViewDelegate>
{
    MKMapView *_allAnnotationsMapView;
    ALAssetsLibrary *assetsLibrary;
    NSMutableArray *assets;
}

@property (strong, nonatomic) NSArray *photos;
@property (nonatomic) BOOL assetsLoaded;

@property (weak, nonatomic) IBOutlet MKMapView *mapView;

@end
