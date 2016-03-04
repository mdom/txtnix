#!/bin/sh

fatten --include-dir lib --use App::txtnix --include File::Spec --include IO::Pager::Unbuffered --exclude Net::SSLeay --exclude IO::Socket::SSL::PublicSuffix --exclude IO::Socket::SSL --exclude EV --overwrite --quiet --strip bin/txtnix txtnix
